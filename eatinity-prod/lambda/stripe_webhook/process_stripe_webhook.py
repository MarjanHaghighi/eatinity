import json
import os
import base64
import traceback
from decimal import Decimal
from datetime import datetime, timezone

import boto3
import stripe

_stripe_secrets = None


def configure_stripe():
    """Load Stripe API and webhook credentials once per warm runtime."""
    global _stripe_secrets
    if _stripe_secrets is None:
        secret_arn = os.environ["STRIPE_SECRET_ARN"]
        response = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
        _stripe_secrets = json.loads(response["SecretString"])
    stripe.api_key = _stripe_secrets["stripe_secret_key"]
    return _stripe_secrets["stripe_webhook_secret"]

dynamodb = boto3.resource("dynamodb")
sns = boto3.client("sns")
ses = boto3.client("ses", region_name=os.environ.get("AWS_REGION", "us-east-1"))

orders_table = dynamodb.Table(os.environ["ORDERS_TABLE_NAME"])

SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
SES_FROM_EMAIL = os.environ["SES_FROM_EMAIL"]


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json"
        },
        "body": json.dumps(body)
    }


def get_header(headers, name):
    if not headers:
        return None

    for key, value in headers.items():
        if key.lower() == name.lower():
            return value

    return None


def safe_get(obj, key, default=None):
    if isinstance(obj, dict):
        return obj.get(key, default)

    try:
        return obj[key]
    except Exception:
        return default


def format_money(amount):
    return f"{float(amount):.2f}"


def build_item_lines(items):
    if not items:
        return "No item details found.\n"

    lines = ""

    for item in items:
        lines += (
            f"- {safe_get(item, 'quantity', '')} x "
            f"{safe_get(item, 'name', 'Item')} "
            f"(${safe_get(item, 'price', '0.00')})\n"
        )

    return lines


def build_address_text(delivery_method, address):
    if str(delivery_method).lower() != "delivery":
        return ""

    if not isinstance(address, dict):
        return ""

    return f"""
Delivery Address:
{address.get("street", "")}
{address.get("city", "")}
{address.get("postalCode", "")}
"""


def lambda_handler(event, context):
    try:
        stripe_webhook_secret = configure_stripe()
        print("Webhook Lambda started")

        payload = event.get("body", "")

        if event.get("isBase64Encoded"):
            payload = base64.b64decode(payload).decode("utf-8")

        sig_header = get_header(event.get("headers", {}), "Stripe-Signature")

        if not sig_header:
            print("Missing Stripe signature header")
            return response(400, {"error": "Missing Stripe signature header."})

        try:
            stripe_event = stripe.Webhook.construct_event(
                payload=payload,
                sig_header=sig_header,
                secret=stripe_webhook_secret
            )
        except ValueError:
            print("Invalid webhook payload")
            return response(400, {"error": "Invalid webhook payload."})
        except stripe.error.SignatureVerificationError:
            print("Invalid Stripe signature")
            return response(400, {"error": "Invalid Stripe signature."})

        event_type = safe_get(stripe_event, "type")
        print("Stripe event type:", event_type)

        if event_type != "checkout.session.completed":
            return response(200, {"received": True, "ignored": True})

        session = safe_get(safe_get(stripe_event, "data", {}), "object", {})

        order_id = safe_get(safe_get(session, "metadata", {}), "orderId")
        stripe_session_id = safe_get(session, "id", "unknown")
        payment_status = safe_get(session, "payment_status", "unknown")
        payment_intent = safe_get(session, "payment_intent", "unknown")
        amount = Decimal(str(safe_get(session, "amount_total", 0))) / Decimal("100")
        currency = safe_get(session, "currency", "cad").upper()
        paid_at = datetime.now(timezone.utc).isoformat()

        print("Order ID from Stripe:", order_id)

        if not order_id:
            raise Exception("No orderId found in Stripe metadata.")

        order_response = orders_table.get_item(Key={"orderId": order_id})
        order = order_response.get("Item")

        if not order:
            raise Exception(f"Order not found in DynamoDB: {order_id}")

        if (
            order.get("paymentStatus") == "Paid"
            and order.get("emailSent") is True
            and order.get("snsSent") is True
        ):
            print("Order already fully processed:", order_id)
            return response(200, {
                "received": True,
                "message": "Order already processed."
            })

        orders_table.update_item(
            Key={"orderId": order_id},
            UpdateExpression="""
                SET paymentStatus = :paid,
                    stripeSessionId = :sid,
                    stripePaymentIntentId = :pi,
                    amountPaid = :amount,
                    currency = :currency,
                    paidAt = :paidAt,
                    updatedAt = :updatedAt
            """,
            ExpressionAttributeValues={
                ":paid": "Paid",
                ":sid": stripe_session_id,
                ":pi": payment_intent,
                ":amount": amount,
                ":currency": currency,
                ":paidAt": paid_at,
                ":updatedAt": paid_at
            }
        )

        print("DynamoDB payment status updated")

        customer_details = safe_get(session, "customer_details", {}) or {}

        customer_name = order.get(
            "customerName",
            safe_get(customer_details, "name", "Customer")
        )

        customer_email = order.get(
            "customerEmail",
            safe_get(customer_details, "email", "")
        )

        customer_phone = order.get(
            "customerPhone",
            safe_get(customer_details, "phone", "Unknown")
        )

        delivery_method = order.get("deliveryMethod", "Unknown")
        address = order.get("address", {})
        items = order.get("items", [])

        item_lines = build_item_lines(items)
        address_text = build_address_text(delivery_method, address)

        admin_message = f"""
NEW PAID EATINITY ORDER

Order ID:
{order_id}

Customer:
{customer_name}

Email:
{customer_email}

Phone:
{customer_phone}

Delivery Method:
{delivery_method}
{address_text}

Items:
{item_lines}

Amount Paid:
${format_money(amount)} {currency}

Payment Status:
{payment_status}

Kitchen Status:
Pending

Action Required:
Please start preparing this order.

Fresh. Healthy. Delivered.
"""

        if not order.get("snsSent"):
            try:
                sns.publish(
                    TopicArn=SNS_TOPIC_ARN,
                    Subject=f"New Paid Eatinity Order - {order_id}",
                    Message=admin_message
                )

                orders_table.update_item(
                    Key={"orderId": order_id},
                    UpdateExpression="SET snsSent = :true REMOVE snsError",
                    ExpressionAttributeValues={
                        ":true": True
                    }
                )

                print("SNS sent successfully")

            except Exception as sns_err:
                print("SNS publish failed:", str(sns_err))
                print(traceback.format_exc())

                orders_table.update_item(
                    Key={"orderId": order_id},
                    UpdateExpression="SET snsSent = :false, snsError = :error",
                    ExpressionAttributeValues={
                        ":false": False,
                        ":error": str(sns_err)
                    }
                )
        else:
            print("SNS already sent, skipping duplicate notification")

        if customer_email and not order.get("emailSent"):
            customer_message = f"""
Hi {customer_name},

Thank you for your Eatinity order!

Your order has been received and payment was successful.

Order ID:
{order_id}

Items:
{item_lines}

Total Paid:
${format_money(amount)} {currency}

Delivery Method:
{delivery_method}
{address_text}

We will start preparing your fresh and healthy meal shortly.

Thank you,
Eatinity
"""

            try:
                ses.send_email(
                    Source=SES_FROM_EMAIL,
                    Destination={
                        "ToAddresses": [customer_email]
                    },
                    Message={
                        "Subject": {
                            "Data": f"Eatinity Order Confirmation - {order_id}"
                        },
                        "Body": {
                            "Text": {
                                "Data": customer_message
                            }
                        }
                    }
                )

                orders_table.update_item(
                    Key={"orderId": order_id},
                    UpdateExpression="SET emailSent = :true REMOVE emailError",
                    ExpressionAttributeValues={
                        ":true": True
                    }
                )

                print("SES email sent successfully")

            except Exception as ses_err:
                print("SES send failed:", str(ses_err))
                print(traceback.format_exc())

                orders_table.update_item(
                    Key={"orderId": order_id},
                    UpdateExpression="SET emailSent = :false, emailError = :error",
                    ExpressionAttributeValues={
                        ":false": False,
                        ":error": str(ses_err)
                    }
                )

        elif not customer_email:
            print("No customer email found, SES skipped")
        else:
            print("Customer email already sent, skipping duplicate notification")

        return response(200, {
            "received": True,
            "orderId": order_id,
            "message": "Webhook processed. Check snsSent/emailSent flags for notification result."
        })

    except Exception as e:
        print("Webhook error:", str(e))
        print(traceback.format_exc())

        return response(500, {
            "error": str(e)
        })

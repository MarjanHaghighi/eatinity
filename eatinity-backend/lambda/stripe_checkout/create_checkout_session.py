import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal, ROUND_HALF_UP

import boto3
import stripe

_stripe_secret = None


def configure_stripe():
    """Load Stripe credentials from Secrets Manager once per warm runtime."""
    global _stripe_secret
    if _stripe_secret is None:
        secret_arn = os.environ["STRIPE_SECRET_ARN"]
        response = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
        payload = json.loads(response["SecretString"])
        _stripe_secret = payload["stripe_secret_key"]
    stripe.api_key = _stripe_secret

dynamodb = boto3.resource("dynamodb")
orders_table = dynamodb.Table(os.environ.get("ORDERS_TABLE_NAME", "EatinityOrders"))
products_table = dynamodb.Table(os.environ.get("PRODUCTS_TABLE_NAME", "EatinityProducts"))

SUCCESS_URL = os.environ.get(
    "SUCCESS_URL",
    "https://eatinity.ca/success?session_id={CHECKOUT_SESSION_ID}"
)
CANCEL_URL = os.environ.get(
    "CANCEL_URL",
    "https://eatinity.ca/cancel"
)


def money(value):
    return Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "POST,OPTIONS",
            "Content-Type": "application/json"
        },
        "body": json.dumps(body)
    }


def get_claims(event):
    return (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )


def load_products(requested_items):
    if not isinstance(requested_items, list) or not requested_items:
        raise ValueError("Cart is empty.")
    if len(requested_items) > 50:
        raise ValueError("Cart cannot contain more than 50 different products.")

    quantities = {}
    product_ids = []
    for requested in requested_items:
        product_id = str(requested.get("id", "")).strip()
        if not product_id:
            raise ValueError("Every cart item must have a product ID.")
        if product_id in quantities:
            raise ValueError("Duplicate product IDs are not allowed in the cart.")
        try:
            quantity = int(requested.get("quantity", 1))
        except (TypeError, ValueError) as error:
            raise ValueError("Product quantity must be a whole number.") from error
        if quantity < 1 or quantity > 99:
            raise ValueError("Product quantity must be between 1 and 99.")
        product_ids.append(product_id)
        quantities[product_id] = quantity

    result = dynamodb.batch_get_item(
        RequestItems={
            products_table.name: {
                "Keys": [{"id": product_id} for product_id in product_ids]
            }
        }
    )
    products = {
        item["id"]: item
        for item in result.get("Responses", {}).get(products_table.name, [])
    }
    if result.get("UnprocessedKeys"):
        raise RuntimeError("Could not validate all cart products. Please try again.")

    validated = []
    for product_id in product_ids:
        product = products.get(product_id)
        if not product:
            raise ValueError(f"Product no longer exists: {product_id}")
        if product.get("available") is False or product.get("archived") is True:
            raise ValueError(f"Product is currently unavailable: {product.get('name', product_id)}")
        validated.append((product, quantities[product_id]))
    return validated


def lambda_handler(event, context):
    try:
        configure_stripe()
        if event.get("requestContext", {}).get("http", {}).get("method") == "OPTIONS":
            return response(200, {"message": "CORS OK"})

        raw_body = event.get("body")
        body = json.loads(raw_body) if raw_body else event

        items = load_products(body.get("items", []))
        customer = body.get("customer", {})

        customer_name = customer.get("name", "").strip()
        customer_email = customer.get("email", "").strip()
        customer_phone = customer.get("phone", "").strip()
        user_id = get_claims(event).get("sub", "")
        delivery_method = customer.get("deliveryMethod", "Delivery")
        address = customer.get("address", {})

        if not customer_name:
            raise Exception("Customer name is required.")
        if not customer_email:
            raise Exception("Customer email is required.")
        if not customer_phone:
            raise Exception("Customer phone is required.")

        order_id = (
            "EN-"
            + datetime.now(timezone.utc).strftime("%Y%m%d")
            + "-"
            + str(uuid.uuid4())[:8].upper()
        )

        line_items = []
        clean_items = []
        total_amount = Decimal("0.00")

        for item, quantity in items:
            product_id = item["id"]
            name = str(item.get("name", "Eatinity Item")).strip()
            price = money(item.get("price", "0"))

            if not name:
                name = "Eatinity Item"
            if price <= 0:
                raise Exception(f"Invalid price for item: {name}")
            if quantity <= 0:
                raise Exception(f"Invalid quantity for item: {name}")

            subtotal = money(price * quantity)
            total_amount += subtotal

            clean_items.append({
                "id": product_id,
                "name": name,
                "category": item.get("category", ""),
                "price": str(price),
                "quantity": quantity,
                "subtotal": str(subtotal)
            })

            line_items.append({
                "price_data": {
                    "currency": "cad",
                    "product_data": {
                        "name": name
                    },
                    "unit_amount": int(price * 100)
                },
                "quantity": quantity
            })

        subtotal_amount = money(total_amount)
        tax_amount = money(subtotal_amount * Decimal("0.13"))
        total_amount = money(subtotal_amount + tax_amount)

        if tax_amount > 0:
            line_items.append({
                "price_data": {
                    "currency": "cad",
                    "product_data": {
                        "name": "HST 13%"
                    },
                    "unit_amount": int(tax_amount * 100)
                },
                "quantity": 1
            })

        order_record = {
            "orderId": order_id,
            "createdAt": datetime.now(timezone.utc).isoformat(),
            "customerName": customer_name,
            "customerEmail": customer_email,
            "customerPhone": customer_phone,
            "userId": user_id,
            "deliveryMethod": delivery_method,
            "address": address,
            "items": clean_items,
            "subtotalAmount": str(subtotal_amount),
            "taxAmount": str(tax_amount),
            "totalAmount": str(total_amount),
            "currency": "CAD",
            "paymentStatus": "Pending Payment",
            "orderStatus": "Pending",
            "stripeSessionId": "",
            "stripePaymentIntentId": "",
            "emailSent": False,
            "snsSent": False
        }

        orders_table.put_item(
            Item=order_record,
            ConditionExpression="attribute_not_exists(orderId)"
        )

        session = stripe.checkout.Session.create(
            payment_method_types=["card"],
            mode="payment",
            customer_email=customer_email,
            line_items=line_items,
            metadata={
                "orderId": order_id,
                "userId": user_id
            },
            success_url=f"{SUCCESS_URL}&order_id={order_id}",
            cancel_url=f"{CANCEL_URL}?order_id={order_id}"
        )

        orders_table.update_item(
            Key={"orderId": order_id},
            UpdateExpression="SET stripeSessionId = :sid",
            ExpressionAttributeValues={
                ":sid": session.id
            }
        )

        return response(200, {
            "url": session.url,
            "orderId": order_id
        })

    except ValueError as e:
        print("Checkout validation error:", str(e))
        return response(400, {"error": str(e)})
    except Exception as e:
        print("Create checkout error:", str(e))
        return response(500, {"error": str(e)})

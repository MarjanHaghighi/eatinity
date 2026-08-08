import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource("dynamodb")
orders_table = dynamodb.Table(os.environ["ORDERS_TABLE_NAME"])
audit_table = dynamodb.Table(os.environ["AUDIT_TABLE_NAME"])
ses = boto3.client("ses", region_name=os.environ.get("AWS_REGION", "us-east-1"))

SES_FROM_EMAIL = os.environ["SES_FROM_EMAIL"]
ADMIN_GROUPS = {"super-admin", "admin", "manager", "kitchen"}
MANAGEMENT_GROUPS = {"super-admin", "admin", "manager"}

TRANSITIONS = {
    "Pending": {"Confirmed", "Cancelled"},
    "Confirmed": {"Preparing", "Cancelled"},
    "Preparing": {"Ready for Pickup", "Out for Delivery", "Cancelled"},
    "Ready for Pickup": {"Picked Up"},
    "Picked Up": {"Completed"},
    "Out for Delivery": {"Delivered"},
}

KITCHEN_TRANSITIONS = {
    ("Confirmed", "Preparing"),
    ("Preparing", "Ready for Pickup"),
    ("Preparing", "Out for Delivery"),
}

PICKUP_STATUS_PATH = ["Pending", "Confirmed", "Preparing", "Ready for Pickup", "Picked Up", "Completed"]
DELIVERY_STATUS_PATH = ["Pending", "Confirmed", "Preparing", "Out for Delivery", "Delivered"]


def json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    return str(value)


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body, default=json_default),
    }


def get_claims(event):
    return (
        event.get("requestContext", {})
        .get("authorizer", {})
        .get("jwt", {})
        .get("claims", {})
    )


def get_groups(claims):
    groups = claims.get("cognito:groups", [])
    if isinstance(groups, list):
        return set(groups)
    if not isinstance(groups, str):
        return set()
    return {
        group.strip().strip("'\"")
        for group in groups.strip("[]").split(",")
        if group.strip()
    }


def parse_body(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError as error:
        raise ValueError("Request body must be valid JSON.") from error


def scan_all(filter_expression=None):
    arguments = {}
    if filter_expression is not None:
        arguments["FilterExpression"] = filter_expression
    result = orders_table.scan(**arguments)
    items = result.get("Items", [])
    while "LastEvaluatedKey" in result:
        arguments["ExclusiveStartKey"] = result["LastEvaluatedKey"]
        result = orders_table.scan(**arguments)
        items.extend(result.get("Items", []))
    return items


def list_orders(query):
    status = str(query.get("status", "")).strip()
    payment_status = str(query.get("paymentStatus", "")).strip()
    delivery_method = str(query.get("deliveryMethod", "")).strip()
    search = str(query.get("search", "")).strip().lower()

    if status:
        result = orders_table.query(
            IndexName="orderStatus-createdAt-index",
            KeyConditionExpression=Key("orderStatus").eq(status),
            ScanIndexForward=False,
        )
        orders = result.get("Items", [])
        while "LastEvaluatedKey" in result:
            result = orders_table.query(
                IndexName="orderStatus-createdAt-index",
                KeyConditionExpression=Key("orderStatus").eq(status),
                ScanIndexForward=False,
                ExclusiveStartKey=result["LastEvaluatedKey"],
            )
            orders.extend(result.get("Items", []))
    else:
        orders = scan_all()

    if payment_status:
        orders = [item for item in orders if item.get("paymentStatus") == payment_status]
    if delivery_method:
        orders = [item for item in orders if str(item.get("deliveryMethod", "")).lower() == delivery_method.lower()]
    if search:
        orders = [item for item in orders if search in " ".join([
            str(item.get("orderId", "")), str(item.get("customerName", "")),
            str(item.get("customerEmail", "")), str(item.get("customerPhone", "")),
        ]).lower()]

    orders.sort(key=lambda item: item.get("createdAt", ""), reverse=True)
    return orders


def expected_ready_status(order):
    method = str(order.get("deliveryMethod", "Pickup")).lower()
    return "Out for Delivery" if method == "delivery" else "Ready for Pickup"


def validate_transition(order, new_status, groups):
    current_status = order.get("orderStatus", "Pending")
    if new_status == current_status:
        return
    if groups.intersection(MANAGEMENT_GROUPS):
        path = DELIVERY_STATUS_PATH if str(order.get("deliveryMethod", "Pickup")).lower() == "delivery" else PICKUP_STATUS_PATH
        if new_status == "Cancelled" and current_status not in {"Completed", "Delivered", "Cancelled"}:
            return
        if current_status in path and new_status in path and path.index(new_status) > path.index(current_status):
            return
        raise ValueError(f"Order cannot move from {current_status} to {new_status}.")
    if new_status not in TRANSITIONS.get(current_status, set()):
        raise ValueError(f"Order cannot move from {current_status} to {new_status}.")
    if current_status == "Preparing" and new_status != "Cancelled":
        expected = expected_ready_status(order)
        if new_status != expected:
            raise ValueError(f"This order must move from Preparing to {expected}.")
    if (current_status, new_status) not in KITCHEN_TRANSITIONS:
        raise PermissionError("Kitchen staff cannot perform this status transition.")


def write_audit(order_id, old_status, new_status, claims, groups, now, request_id):
    audit_table.put_item(Item={
        "auditId": str(uuid.uuid4()),
        "scope": "ADMIN",
        "entityType": "ORDER",
        "entityId": order_id,
        "action": "ORDER_STATUS_CHANGED",
        "actorUserId": claims.get("sub", "unknown"),
        "actorEmail": claims.get("email", ""),
        "actorGroups": sorted(groups),
        "oldValue": {"orderStatus": old_status},
        "newValue": {"orderStatus": new_status},
        "createdAt": now,
        "requestId": request_id,
    })


def send_ready_email(order):
    email = str(order.get("customerEmail", "")).strip()
    if not email:
        raise ValueError("The order does not have a customer email address.")
    name = order.get("customerName", "Customer")
    order_id = order["orderId"]
    ses.send_email(
        Source=SES_FROM_EMAIL,
        Destination={"ToAddresses": [email]},
        Message={
            "Subject": {"Data": f"Your Eatinity order is ready - {order_id}"},
            "Body": {"Text": {"Data": (
                f"Hi {name},\n\nYour Eatinity order {order_id} is ready for pickup.\n\n"
                "Please bring your order confirmation when you arrive.\n\nThank you,\nEatinity"
            )}},
        },
    )


def update_status(order, new_status, claims, groups, request_id):
    old_status = order.get("orderStatus", "Pending")
    validate_transition(order, new_status, groups)
    now = datetime.now(timezone.utc).isoformat()

    if old_status != new_status:
        history_entry = {
            "from": old_status,
            "to": new_status,
            "changedAt": now,
            "changedBy": claims.get("sub", "unknown"),
        }
        try:
            result = orders_table.update_item(
                Key={"orderId": order["orderId"]},
                UpdateExpression=(
                    "SET orderStatus = :new, statusUpdatedAt = :now, statusUpdatedBy = :actor, "
                    "statusHistory = list_append(if_not_exists(statusHistory, :empty), :entry)"
                ),
                ConditionExpression="orderStatus = :old OR attribute_not_exists(orderStatus)",
                ExpressionAttributeValues={
                    ":new": new_status, ":old": old_status, ":now": now,
                    ":actor": claims.get("sub", "unknown"), ":empty": [], ":entry": [history_entry],
                },
                ReturnValues="ALL_NEW",
            )
        except orders_table.meta.client.exceptions.ConditionalCheckFailedException as error:
            raise RuntimeError("This order was changed by another staff member. Refresh and try again.") from error
        updated_order = result["Attributes"]
        write_audit(order["orderId"], old_status, new_status, claims, groups, now, request_id)
    else:
        updated_order = order

    if new_status == "Ready for Pickup" and not updated_order.get("readyNotificationSentAt"):
        try:
            send_ready_email(updated_order)
            notification_time = datetime.now(timezone.utc).isoformat()
            updated_order = orders_table.update_item(
                Key={"orderId": order["orderId"]},
                UpdateExpression="SET readyNotificationSentAt = :sent REMOVE readyNotificationError",
                ExpressionAttributeValues={":sent": notification_time},
                ReturnValues="ALL_NEW",
            )["Attributes"]
        except Exception as error:
            orders_table.update_item(
                Key={"orderId": order["orderId"]},
                UpdateExpression="SET readyNotificationError = :error",
                ExpressionAttributeValues={":error": str(error)},
            )
            raise RuntimeError("Status updated, but the ready email could not be sent.") from error

    return updated_order


def lambda_handler(event, context):
    try:
        claims = get_claims(event)
        groups = get_groups(claims)
        if not groups.intersection(ADMIN_GROUPS):
            return response(403, {"error": "You do not have permission to manage orders."})

        method = event.get("requestContext", {}).get("http", {}).get("method", "")
        path = event.get("rawPath", "")
        params = event.get("pathParameters") or {}
        order_id = params.get("orderId")

        if path == "/admin/orders" and method == "GET":
            return response(200, {"orders": list_orders(event.get("queryStringParameters") or {})})

        if order_id and method == "GET":
            order = orders_table.get_item(Key={"orderId": order_id}).get("Item")
            return response(200, {"order": order}) if order else response(404, {"error": "Order not found."})

        if order_id and path.endswith("/status") and method == "PATCH":
            order = orders_table.get_item(Key={"orderId": order_id}).get("Item")
            if not order:
                return response(404, {"error": "Order not found."})
            new_status = str(parse_body(event).get("orderStatus", "")).strip()
            if not new_status:
                raise ValueError("orderStatus is required.")
            request_id = getattr(context, "aws_request_id", "")
            return response(200, {"order": update_status(order, new_status, claims, groups, request_id)})

        return response(404, {"error": "Admin order route not found."})
    except PermissionError as error:
        return response(403, {"error": str(error)})
    except ValueError as error:
        return response(400, {"error": str(error)})
    except RuntimeError as error:
        return response(409, {"error": str(error)})
    except Exception as error:
        print("Admin orders error:", str(error))
        return response(500, {"error": "Could not process the admin order request."})

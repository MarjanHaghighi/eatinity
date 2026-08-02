import json
import os
from datetime import datetime, timezone
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource("dynamodb")
users_table = dynamodb.Table(os.environ["USERS_TABLE_NAME"])
orders_table = dynamodb.Table(os.environ.get("ORDERS_TABLE_NAME", "EatinityOrders"))


def json_default(value):
    if isinstance(value, Decimal):
        if value % 1 == 0:
            return int(value)
        return float(value)
    return str(value)


def response(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,Authorization",
            "Access-Control-Allow-Methods": "GET,PUT,OPTIONS",
        },
        "body": json.dumps(body, default=json_default),
    }


def get_claims(event):
    authorizer = event.get("requestContext", {}).get("authorizer", {})

    jwt_claims = authorizer.get("jwt", {}).get("claims")
    if jwt_claims:
        return jwt_claims

    rest_claims = authorizer.get("claims")
    if rest_claims:
        return rest_claims

    return {}


def get_method(event):
    method = event.get("requestContext", {}).get("http", {}).get("method")
    if method:
        return method

    return event.get("httpMethod", "")


def get_path(event):
    return event.get("rawPath") or event.get("path") or ""


def get_groups(claims):
    groups = claims.get("cognito:groups", [])

    if isinstance(groups, list):
        return groups

    if isinstance(groups, str):
        return [group.strip() for group in groups.split(",") if group.strip()]

    return []


def build_default_profile(user_id, email, name, role, now):
    return {
        "userId": user_id,
        "email": email,
        "name": name,
        "phone": "",
        "role": role,
        "defaultDeliveryMethod": "Pickup",
        "address": None,
        "createdAt": now,
        "updatedAt": now,
    }


def get_or_create_profile(user_id, email, name, role, now):
    result = users_table.get_item(Key={"userId": user_id})
    profile = result.get("Item")

    if not profile:
        profile = build_default_profile(user_id, email, name, role, now)
        users_table.put_item(Item=profile)

    return profile


def get_user_orders(user_id):
    result = orders_table.query(
        IndexName="userId-index",
        KeyConditionExpression=Key("userId").eq(user_id)
    )

    orders = result.get("Items", [])

    while "LastEvaluatedKey" in result:
        result = orders_table.query(
            IndexName="userId-index",
            KeyConditionExpression=Key("userId").eq(user_id),
            ExclusiveStartKey=result["LastEvaluatedKey"]
        )
        orders.extend(result.get("Items", []))

    orders.sort(key=lambda order: order.get("createdAt", ""), reverse=True)

    return orders


def lambda_handler(event, context):
    try:
        method = get_method(event)
        path = get_path(event)

        if method == "OPTIONS":
            return response(200, {"ok": True})

        claims = get_claims(event)

        user_id = claims.get("sub")
        email = claims.get("email", "")
        name = claims.get("name", "")
        groups = get_groups(claims)

        if not user_id:
            return response(401, {"error": "Unauthorized. Missing Cognito user."})

        role = next(
            (group for group in ["super-admin", "admin", "manager", "kitchen"] if group in groups),
            "customer"
        )
        now = datetime.now(timezone.utc).isoformat()

        if path.endswith("/user-orders") and method == "GET":
            orders = get_user_orders(user_id)
            return response(200, {"orders": orders})

        if path.endswith("/user-profile") and method == "GET":
            profile = get_or_create_profile(user_id, email, name, role, now)
            return response(200, {"profile": profile})

        if path.endswith("/user-profile") and method == "PUT":
            body = json.loads(event.get("body") or "{}")

            existing_profile = get_or_create_profile(user_id, email, name, role, now)

            updated_name = body.get("name", existing_profile.get("name", name))
            phone = body.get("phone", existing_profile.get("phone", ""))
            default_delivery_method = body.get(
                "defaultDeliveryMethod",
                existing_profile.get("defaultDeliveryMethod", "Pickup")
            )
            address = body.get("address", existing_profile.get("address"))

            users_table.update_item(
                Key={"userId": user_id},
                UpdateExpression="""
                    SET email = :email,
                        #name = :name,
                        phone = :phone,
                        #role = :role,
                        defaultDeliveryMethod = :delivery,
                        address = :address,
                        updatedAt = :updatedAt
                """,
                ExpressionAttributeNames={
                    "#name": "name",
                    "#role": "role",
                },
                ExpressionAttributeValues={
                    ":email": email,
                    ":name": updated_name,
                    ":phone": phone,
                    ":role": role,
                    ":delivery": default_delivery_method,
                    ":address": address,
                    ":updatedAt": now,
                },
            )

            result = users_table.get_item(Key={"userId": user_id})
            return response(200, {"profile": result.get("Item")})

        return response(404, {"error": "Route not found."})

    except Exception as error:
        print("Profile Lambda error:", str(error))
        return response(500, {"error": str(error)})

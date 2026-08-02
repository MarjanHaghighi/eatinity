import base64
import json
import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource("dynamodb")
audit_table = dynamodb.Table(os.environ["AUDIT_TABLE_NAME"])


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
    return event.get("requestContext", {}).get("authorizer", {}).get("jwt", {}).get("claims", {})


def get_groups(claims):
    groups = claims.get("cognito:groups", [])
    if isinstance(groups, list):
        return set(groups)
    if not isinstance(groups, str):
        return set()
    return {group.strip().strip("'\"") for group in groups.strip("[]").split(",") if group.strip()}


def encode_cursor(key):
    if not key:
        return None
    return base64.urlsafe_b64encode(json.dumps(key).encode("utf-8")).decode("ascii")


def decode_cursor(cursor):
    if not cursor:
        return None
    try:
        return json.loads(base64.urlsafe_b64decode(cursor.encode("ascii")).decode("utf-8"))
    except Exception as error:
        raise ValueError("Invalid audit cursor.") from error


def list_audit_entries(query):
    try:
        limit = min(max(int(query.get("limit", 50)), 1), 100)
    except (TypeError, ValueError) as error:
        raise ValueError("limit must be a whole number.") from error

    arguments = {
        "IndexName": "scope-createdAt-index",
        "KeyConditionExpression": Key("scope").eq("ADMIN"),
        "ScanIndexForward": False,
        "Limit": limit,
    }
    cursor = decode_cursor(query.get("cursor"))
    if cursor:
        arguments["ExclusiveStartKey"] = cursor

    result = audit_table.query(**arguments)
    entries = result.get("Items", [])
    entity_type = str(query.get("entityType", "")).upper().strip()
    action = str(query.get("action", "")).upper().strip()
    search = str(query.get("search", "")).lower().strip()

    if entity_type:
        entries = [entry for entry in entries if entry.get("entityType") == entity_type]
    if action:
        entries = [entry for entry in entries if entry.get("action") == action]
    if search:
        entries = [entry for entry in entries if search in " ".join([
            str(entry.get("entityId", "")), str(entry.get("actorEmail", "")),
            str(entry.get("actorUserId", "")), str(entry.get("action", "")),
        ]).lower()]

    return entries, encode_cursor(result.get("LastEvaluatedKey"))


def lambda_handler(event, context):
    try:
        if "super-admin" not in get_groups(get_claims(event)):
            return response(403, {"error": "Only a super-admin can view the audit log."})
        entries, cursor = list_audit_entries(event.get("queryStringParameters") or {})
        return response(200, {"entries": entries, "nextCursor": cursor})
    except ValueError as error:
        return response(400, {"error": str(error)})
    except Exception as error:
        print("Admin audit error:", str(error))
        return response(500, {"error": "Could not load the audit log."})

import json
import os
import re
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from urllib.parse import quote

import boto3


dynamodb = boto3.resource("dynamodb")
products_table = dynamodb.Table(os.environ["PRODUCTS_TABLE_NAME"])
categories_table = dynamodb.Table(os.environ["CATEGORIES_TABLE_NAME"])
audit_table = dynamodb.Table(os.environ["AUDIT_TABLE_NAME"])
s3 = boto3.client("s3")

IMAGE_BUCKET_NAME = os.environ["IMAGE_BUCKET_NAME"]
MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
    "image/avif": ".avif",
}

MENU_GROUPS = {"super-admin", "admin", "manager"}
CATEGORY_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


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


def scan_all(table):
    result = table.scan()
    items = result.get("Items", [])
    while "LastEvaluatedKey" in result:
        result = table.scan(ExclusiveStartKey=result["LastEvaluatedKey"])
        items.extend(result.get("Items", []))
    return items


def parse_body(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError as error:
        raise ValueError("Request body must be valid JSON.") from error


def write_audit(action, entity_type, entity_id, old_value, new_value, claims, request_id, now):
    try:
        audit_table.put_item(Item={
            "auditId": str(uuid.uuid4()),
            "scope": "ADMIN",
            "entityType": entity_type,
            "entityId": entity_id,
            "action": action,
            "actorUserId": claims.get("sub", "unknown"),
            "actorEmail": claims.get("email", ""),
            "actorGroups": sorted(get_groups(claims)),
            "oldValue": old_value or {},
            "newValue": new_value or {},
            "createdAt": now,
            "requestId": request_id,
        })
    except Exception as error:
        print("Menu audit write failed:", str(error))


def require_text(body, field):
    value = str(body.get(field, "")).strip()
    if not value:
        raise ValueError(f"{field} is required.")
    return value


def create_image_upload(body):
    category = require_text(body, "category")
    if not CATEGORY_PATTERN.fullmatch(category):
        raise ValueError("category must contain lowercase letters, numbers, and hyphens only.")
    category_item = categories_table.get_item(
        Key={"categoryId": category}
    ).get("Item")
    if not category_item or category_item.get("active") is False:
        raise ValueError("Select an active category before uploading an image.")

    content_type = str(body.get("contentType", "")).lower().strip()
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise ValueError("Image must be JPEG, PNG, WebP, or AVIF.")
    try:
        file_size = int(body.get("fileSize", 0))
    except (TypeError, ValueError) as error:
        raise ValueError("fileSize must be a whole number.") from error
    if file_size < 1 or file_size > MAX_IMAGE_BYTES:
        raise ValueError("Image must be between 1 byte and 5 MB.")

    original_name = str(body.get("fileName", "")).replace("\\", "/").split("/")[-1]
    original_stem = original_name.rsplit(".", 1)[0].strip()
    safe_stem = re.sub(r"[^A-Za-z0-9 _-]+", "-", original_stem)
    safe_stem = re.sub(r"\s+", " ", safe_stem).strip(" .-_")[:80]
    if not safe_stem:
        safe_stem = "image"
    unique_suffix = uuid.uuid4().hex[:12]
    object_key = (
        f"foods/{category}/"
        f"{safe_stem}-{unique_suffix}{ALLOWED_IMAGE_TYPES[content_type]}"
    )
    image_path = quote(object_key, safe="/")
    upload = s3.generate_presigned_post(
        Bucket=IMAGE_BUCKET_NAME,
        Key=object_key,
        Fields={"Content-Type": content_type},
        Conditions=[
            {"Content-Type": content_type},
            ["content-length-range", 1, MAX_IMAGE_BYTES],
        ],
        ExpiresIn=300,
    )
    return {"imagePath": image_path, "upload": upload}


def parse_price(value):
    try:
        price = Decimal(str(value)).quantize(Decimal("0.01"))
    except (InvalidOperation, TypeError, ValueError) as error:
        raise ValueError("price must be a valid number.") from error
    if price <= 0:
        raise ValueError("price must be greater than zero.")
    return price


def parse_display_order(value, default=0):
    try:
        order = int(value if value is not None else default)
    except (TypeError, ValueError) as error:
        raise ValueError("displayOrder must be a whole number.") from error
    if order < 0:
        raise ValueError("displayOrder cannot be negative.")
    return order


def ensure_category(category):
    if not CATEGORY_PATTERN.fullmatch(category):
        raise ValueError("category must contain lowercase letters, numbers, and hyphens only.")
    result = categories_table.get_item(Key={"categoryId": category})
    item = result.get("Item")
    if not item or item.get("active") is False:
        raise ValueError("Select an active menu category.")


def create_product(body, actor_id, now):
    name = require_text(body, "name")
    category = require_text(body, "category").lower()
    ensure_category(category)
    product_id = str(body.get("id") or f"p-{uuid.uuid4().hex[:10]}")
    item = {
        "id": product_id,
        "name": name,
        "description": str(body.get("description", "")).strip(),
        "category": category,
        "price": parse_price(body.get("price")),
        "imagePath": str(body.get("imagePath", "")).strip(),
        "available": bool(body.get("available", True)),
        "featured": bool(body.get("featured", False)),
        "archived": False,
        "displayOrder": parse_display_order(body.get("displayOrder")),
        "ingredients": body.get("ingredients", []),
        "allergens": body.get("allergens", []),
        "createdAt": now,
        "updatedAt": now,
        "updatedBy": actor_id,
    }
    products_table.put_item(
        Item=item,
        ConditionExpression="attribute_not_exists(id)",
    )
    return item


def update_product(product_id, body, actor_id, now):
    current = products_table.get_item(Key={"id": product_id}).get("Item")
    if not current:
        return None
    category = str(body.get("category", current.get("category", ""))).strip().lower()
    ensure_category(category)
    updated = {
        **current,
        "name": str(body.get("name", current.get("name", ""))).strip(),
        "description": str(body.get("description", current.get("description", ""))).strip(),
        "category": category,
        "price": parse_price(body.get("price", current.get("price"))),
        "imagePath": str(body.get("imagePath", current.get("imagePath", ""))).strip(),
        "available": bool(body.get("available", current.get("available", True))),
        "featured": bool(body.get("featured", current.get("featured", False))),
        "displayOrder": parse_display_order(body.get("displayOrder"), current.get("displayOrder", 0)),
        "ingredients": body.get("ingredients", current.get("ingredients", [])),
        "allergens": body.get("allergens", current.get("allergens", [])),
        "updatedAt": now,
        "updatedBy": actor_id,
    }
    if not updated["name"]:
        raise ValueError("name is required.")
    products_table.put_item(Item=updated)
    return updated


def set_product_availability(product_id, body, actor_id, now):
    if "available" not in body or not isinstance(body["available"], bool):
        raise ValueError("available must be true or false.")
    try:
        result = products_table.update_item(
            Key={"id": product_id},
            UpdateExpression="SET available = :available, updatedAt = :now, updatedBy = :actor",
            ConditionExpression="attribute_exists(id)",
            ExpressionAttributeValues={
                ":available": body["available"],
                ":now": now,
                ":actor": actor_id,
            },
            ReturnValues="ALL_NEW",
        )
    except products_table.meta.client.exceptions.ConditionalCheckFailedException:
        return None
    return result.get("Attributes")


def archive_product(product_id, actor_id, now):
    try:
        result = products_table.update_item(
            Key={"id": product_id},
            UpdateExpression=(
                "SET archived = :true, available = :false, "
                "updatedAt = :now, updatedBy = :actor"
            ),
            ConditionExpression="attribute_exists(id)",
            ExpressionAttributeValues={
                ":true": True,
                ":false": False,
                ":now": now,
                ":actor": actor_id,
            },
            ReturnValues="ALL_NEW",
        )
    except products_table.meta.client.exceptions.ConditionalCheckFailedException:
        return None
    return result.get("Attributes")


def restore_product(product_id, actor_id, now):
    try:
        result = products_table.update_item(
            Key={"id": product_id},
            UpdateExpression=(
                "SET archived = :false, available = :true, "
                "updatedAt = :now, updatedBy = :actor"
            ),
            ConditionExpression="attribute_exists(id)",
            ExpressionAttributeValues={
                ":false": False,
                ":true": True,
                ":now": now,
                ":actor": actor_id,
            },
            ReturnValues="ALL_NEW",
        )
    except products_table.meta.client.exceptions.ConditionalCheckFailedException:
        return None
    return result.get("Attributes")


def save_category(body, actor_id, now, category_id=None):
    resolved_id = (category_id or require_text(body, "categoryId")).lower()
    if not CATEGORY_PATTERN.fullmatch(resolved_id):
        raise ValueError("categoryId must contain lowercase letters, numbers, and hyphens only.")
    current = categories_table.get_item(Key={"categoryId": resolved_id}).get("Item", {})
    name = str(body.get("name", current.get("name", ""))).strip()
    if not name:
        raise ValueError("name is required.")
    item = {
        **current,
        "categoryId": resolved_id,
        "name": name,
        "description": str(body.get("description", current.get("description", ""))).strip(),
        "displayOrder": parse_display_order(body.get("displayOrder"), current.get("displayOrder", 0)),
        "active": bool(body.get("active", current.get("active", True))),
        "createdAt": current.get("createdAt", now),
        "updatedAt": now,
        "updatedBy": actor_id,
    }
    categories_table.put_item(Item=item)
    return item


def lambda_handler(event, context):
    try:
        method = event.get("requestContext", {}).get("http", {}).get("method", "")
        path = event.get("rawPath", "")

        if path == "/categories" and method == "GET":
            categories = [
                category
                for category in scan_all(categories_table)
                if category.get("active") is not False
            ]
            categories.sort(key=lambda item: (item.get("displayOrder", 0), item.get("name", "")))
            return response(200, {"categories": categories})

        claims = get_claims(event)
        if not get_groups(claims).intersection(MENU_GROUPS):
            return response(403, {"error": "You do not have permission to manage the menu."})

        params = event.get("pathParameters") or {}
        actor_id = claims.get("sub", "unknown")
        now = datetime.now(timezone.utc).isoformat()
        request_id = getattr(context, "aws_request_id", "")

        if path == "/admin/products" and method == "GET":
            products = scan_all(products_table)
            products.sort(key=lambda item: (item.get("category", ""), item.get("displayOrder", 0), item.get("name", "")))
            return response(200, {"products": products})

        if path == "/admin/uploads/product-image" and method == "POST":
            return response(200, create_image_upload(parse_body(event)))

        if path == "/admin/products" and method == "POST":
            product = create_product(parse_body(event), actor_id, now)
            write_audit("PRODUCT_CREATED", "PRODUCT", product["id"], {}, product, claims, request_id, now)
            return response(201, {"product": product})

        product_id = params.get("productId")
        if product_id and method == "PUT":
            old_product = products_table.get_item(Key={"id": product_id}).get("Item")
            product = update_product(product_id, parse_body(event), actor_id, now)
            if product:
                write_audit("PRODUCT_UPDATED", "PRODUCT", product_id, old_product, product, claims, request_id, now)
            return response(200, {"product": product}) if product else response(404, {"error": "Product not found."})

        if product_id and path.endswith("/availability") and method == "PATCH":
            old_product = products_table.get_item(Key={"id": product_id}).get("Item")
            product = set_product_availability(product_id, parse_body(event), actor_id, now)
            if product:
                write_audit("PRODUCT_AVAILABILITY_CHANGED", "PRODUCT", product_id, old_product, product, claims, request_id, now)
            return response(200, {"product": product}) if product else response(404, {"error": "Product not found."})

        if product_id and path.endswith("/restore") and method == "PATCH":
            old_product = products_table.get_item(Key={"id": product_id}).get("Item")
            product = restore_product(product_id, actor_id, now)
            if product:
                write_audit("PRODUCT_RESTORED", "PRODUCT", product_id, old_product, product, claims, request_id, now)
            return response(200, {"product": product}) if product else response(404, {"error": "Product not found."})

        if product_id and method == "DELETE":
            old_product = products_table.get_item(Key={"id": product_id}).get("Item")
            product = archive_product(product_id, actor_id, now)
            if product:
                write_audit("PRODUCT_ARCHIVED", "PRODUCT", product_id, old_product, product, claims, request_id, now)
            return response(200, {"product": product}) if product else response(404, {"error": "Product not found."})

        if path == "/admin/categories" and method == "GET":
            categories = scan_all(categories_table)
            categories.sort(key=lambda item: (item.get("displayOrder", 0), item.get("name", "")))
            return response(200, {"categories": categories})

        if path == "/admin/categories" and method == "POST":
            category = save_category(parse_body(event), actor_id, now)
            write_audit("CATEGORY_CREATED", "CATEGORY", category["categoryId"], {}, category, claims, request_id, now)
            return response(201, {"category": category})

        category_id = params.get("categoryId")
        if category_id and method == "PUT":
            old_category = categories_table.get_item(Key={"categoryId": category_id}).get("Item")
            category = save_category(parse_body(event), actor_id, now, category_id)
            write_audit("CATEGORY_UPDATED", "CATEGORY", category_id, old_category, category, claims, request_id, now)
            return response(200, {"category": category})

        return response(404, {"error": "Admin menu route not found."})
    except ValueError as error:
        return response(400, {"error": str(error)})
    except Exception as error:
        print("Admin menu error:", str(error))
        return response(500, {"error": "Could not process the admin menu request."})

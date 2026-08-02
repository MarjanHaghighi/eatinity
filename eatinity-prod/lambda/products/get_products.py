import os
import json
import boto3
from decimal import Decimal
from boto3.dynamodb.conditions import Attr

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(os.environ["PRODUCTS_TABLE_NAME"])

IMAGE_BASE_URL = os.environ["IMAGE_BASE_URL"]

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


def lambda_handler(event, context):
    response = table.scan(
        FilterExpression=(Attr("archived").eq(False) | Attr("archived").not_exists())
    )
    products = response.get("Items", [])

    while "LastEvaluatedKey" in response:
        response = table.scan(
            FilterExpression=(Attr("archived").eq(False) | Attr("archived").not_exists()),
            ExclusiveStartKey=response["LastEvaluatedKey"]
        )
        products.extend(response.get("Items", []))

    products.sort(
        key=lambda product: (
            product.get("category", ""),
            product.get("displayOrder", 0),
            product.get("name", "")
        )
    )

    for product in products:
        product["image"] = IMAGE_BASE_URL + product.get("imagePath", "")

    return {
        "statusCode": 200,
        "headers": {
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "*",
            "Access-Control-Allow-Methods": "GET,OPTIONS"
        },
        "body": json.dumps(products, cls=DecimalEncoder)
    }

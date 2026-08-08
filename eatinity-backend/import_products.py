import json
import boto3
from decimal import Decimal

TABLE_NAME = "EatinityProducts"

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def convert_float_to_decimal(obj):
    if isinstance(obj, list):
        return [convert_float_to_decimal(item) for item in obj]
    if isinstance(obj, dict):
        return {key: convert_float_to_decimal(value) for key, value in obj.items()}
    if isinstance(obj, float):
        return Decimal(str(obj))
    return obj


with open("products.json", "r", encoding="utf-8") as file:
    products = json.load(file)

products = convert_float_to_decimal(products)

for product in products:
    table.put_item(Item=product)
    print(f"Imported: {product['name']}")

print("All products imported successfully.")
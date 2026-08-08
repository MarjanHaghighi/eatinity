import argparse
import json
from datetime import datetime, timezone
from decimal import Decimal
from pathlib import Path

import boto3


def convert_numbers(value):
    if isinstance(value, list):
        return [convert_numbers(item) for item in value]
    if isinstance(value, dict):
        return {key: convert_numbers(item) for key, item in value.items()}
    if isinstance(value, float):
        return Decimal(str(value))
    return value


def main():
    parser = argparse.ArgumentParser(description="Create Eatinity's default menu categories once.")
    parser.add_argument("--table", default="EatinityCategories")
    args = parser.parse_args()

    source = Path(__file__).with_name("default_categories.json")
    categories = convert_numbers(json.loads(source.read_text(encoding="utf-8")))
    table = boto3.resource("dynamodb").Table(args.table)
    now = datetime.now(timezone.utc).isoformat()

    for category in categories:
        table.put_item(
            Item={**category, "createdAt": now, "updatedAt": now, "updatedBy": "bootstrap"},
            ConditionExpression="attribute_not_exists(categoryId)",
        )
        print(f"Created category: {category['categoryId']}")


if __name__ == "__main__":
    main()

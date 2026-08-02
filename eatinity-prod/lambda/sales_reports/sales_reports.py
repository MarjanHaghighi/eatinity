import json
import os
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from zoneinfo import ZoneInfo

import boto3
from boto3.dynamodb.conditions import Key


dynamodb = boto3.resource("dynamodb")
orders_table = dynamodb.Table(os.environ["ORDERS_TABLE_NAME"])

REPORT_GROUPS = {"super-admin", "admin", "manager"}
BUSINESS_TIMEZONE = ZoneInfo(os.environ.get("BUSINESS_TIMEZONE", "America/Toronto"))


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


def local_day_start(day):
    return datetime.combine(day, time.min, BUSINESS_TIMEZONE)


def parse_date(value, field):
    try:
        return date.fromisoformat(value)
    except (TypeError, ValueError) as error:
        raise ValueError(f"{field} must use YYYY-MM-DD format.") from error


def resolve_period(query):
    period = str(query.get("period", "today")).lower()
    today = datetime.now(BUSINESS_TIMEZONE).date()

    if period == "today":
        start_local = local_day_start(today)
        end_local = start_local + timedelta(days=1)
        group_by = "hour"
    elif period == "daily":
        start_local = local_day_start(today - timedelta(days=6))
        end_local = local_day_start(today + timedelta(days=1))
        group_by = "day"
    elif period == "weekly":
        current_week = today - timedelta(days=today.weekday())
        start_local = local_day_start(current_week - timedelta(weeks=7))
        end_local = local_day_start(current_week + timedelta(weeks=1))
        group_by = "week"
    elif period == "monthly":
        first_this_month = today.replace(day=1)
        start_year = first_this_month.year
        start_month = first_this_month.month - 11
        while start_month <= 0:
            start_month += 12
            start_year -= 1
        start_local = local_day_start(date(start_year, start_month, 1))
        if first_this_month.month == 12:
            next_month = date(first_this_month.year + 1, 1, 1)
        else:
            next_month = date(first_this_month.year, first_this_month.month + 1, 1)
        end_local = local_day_start(next_month)
        group_by = "month"
    elif period == "custom":
        start_day = parse_date(query.get("startDate"), "startDate")
        end_day = parse_date(query.get("endDate"), "endDate")
        if end_day < start_day:
            raise ValueError("endDate cannot be before startDate.")
        if (end_day - start_day).days > 366:
            raise ValueError("Custom reports cannot exceed 366 days.")
        start_local = local_day_start(start_day)
        end_local = local_day_start(end_day + timedelta(days=1))
        group_by = "day"
    else:
        raise ValueError("period must be today, daily, weekly, monthly, or custom.")

    return period, start_local, end_local, group_by


def query_paid_orders(start_local, end_local):
    start_utc = start_local.astimezone(timezone.utc).isoformat()
    end_utc = (end_local.astimezone(timezone.utc) - timedelta(microseconds=1)).isoformat()
    result = orders_table.query(
        IndexName="paymentStatus-paidAt-index",
        KeyConditionExpression=(
            Key("paymentStatus").eq("Paid")
            & Key("paidAt").between(start_utc, end_utc)
        ),
    )
    orders = result.get("Items", [])
    while "LastEvaluatedKey" in result:
        result = orders_table.query(
            IndexName="paymentStatus-paidAt-index",
            KeyConditionExpression=(
                Key("paymentStatus").eq("Paid")
                & Key("paidAt").between(start_utc, end_utc)
            ),
            ExclusiveStartKey=result["LastEvaluatedKey"],
        )
        orders.extend(result.get("Items", []))
    return orders


def money(value):
    return Decimal(str(value or "0"))


def bucket_key(timestamp, group_by):
    local_time = datetime.fromisoformat(timestamp).astimezone(BUSINESS_TIMEZONE)
    if group_by == "hour":
        return local_time.strftime("%Y-%m-%dT%H:00")
    if group_by == "day":
        return local_time.strftime("%Y-%m-%d")
    if group_by == "week":
        week_start = local_time.date() - timedelta(days=local_time.weekday())
        return week_start.isoformat()
    return local_time.strftime("%Y-%m")


def empty_bucket():
    return {
        "sales": Decimal("0"), "orders": 0, "items": 0,
        "products": defaultdict(lambda: {"quantity": 0, "sales": Decimal("0")}),
        "deliveryMethods": defaultdict(lambda: {"orders": 0, "sales": Decimal("0")}),
    }


def build_report(orders, period, start_local, end_local, group_by):
    gross_sales = Decimal("0")
    subtotal = Decimal("0")
    tax = Decimal("0")
    items_sold = 0
    products = defaultdict(lambda: {"quantity": 0, "sales": Decimal("0")})
    delivery_methods = defaultdict(lambda: {"orders": 0, "sales": Decimal("0")})
    buckets = defaultdict(empty_bucket)

    for order in orders:
        total = money(order.get("amountPaid") or order.get("totalAmount"))
        order_subtotal = money(order.get("subtotalAmount"))
        order_tax = money(order.get("taxAmount"))
        gross_sales += total
        subtotal += order_subtotal
        tax += order_tax
        method = str(order.get("deliveryMethod", "Unknown"))
        delivery_methods[method]["orders"] += 1
        delivery_methods[method]["sales"] += total

        bucket = buckets[bucket_key(order["paidAt"], group_by)]
        bucket["sales"] += total
        bucket["orders"] += 1
        bucket["deliveryMethods"][method]["orders"] += 1
        bucket["deliveryMethods"][method]["sales"] += total

        for item in order.get("items", []):
            quantity = int(item.get("quantity", 1))
            item_sales = money(item.get("price")) * quantity
            name = str(item.get("name", "Unknown Item"))
            products[name]["quantity"] += quantity
            products[name]["sales"] += item_sales
            items_sold += quantity
            bucket["items"] += quantity
            bucket["products"][name]["quantity"] += quantity
            bucket["products"][name]["sales"] += item_sales

    order_count = len(orders)
    average = gross_sales / order_count if order_count else Decimal("0")
    series = []
    for label, values in sorted(buckets.items()):
        series.append({
            "label": label,
            "sales": values["sales"],
            "orders": values["orders"],
            "items": values["items"],
            "products": [
                {"name": name, **totals}
                for name, totals in sorted(values["products"].items(), key=lambda item: item[1]["sales"], reverse=True)
            ],
            "deliveryMethods": [
                {"method": method, **totals}
                for method, totals in sorted(values["deliveryMethods"].items())
            ],
        })
    product_rows = [
        {"name": name, **values}
        for name, values in sorted(products.items(), key=lambda item: item[1]["sales"], reverse=True)
    ]
    method_rows = [{"method": method, **values} for method, values in sorted(delivery_methods.items())]

    return {
        "period": period,
        "timezone": str(BUSINESS_TIMEZONE),
        "startDate": start_local.date().isoformat(),
        "endDate": (end_local.date() - timedelta(days=1)).isoformat(),
        "groupBy": group_by,
        "summary": {
            "grossSales": gross_sales,
            "subtotal": subtotal,
            "taxCollected": tax,
            "paidOrderCount": order_count,
            "averageOrderValue": average.quantize(Decimal("0.01")),
            "itemsSold": items_sold,
        },
        "series": series,
        "products": product_rows,
        "deliveryMethods": method_rows,
    }


def lambda_handler(event, context):
    try:
        if not get_groups(get_claims(event)).intersection(REPORT_GROUPS):
            return response(403, {"error": "You do not have permission to view sales reports."})
        query = event.get("queryStringParameters") or {}
        period, start_local, end_local, group_by = resolve_period(query)
        orders = query_paid_orders(start_local, end_local)
        return response(200, {"report": build_report(orders, period, start_local, end_local, group_by)})
    except ValueError as error:
        return response(400, {"error": str(error)})
    except Exception as error:
        print("Sales report error:", str(error))
        return response(500, {"error": "Could not generate the sales report."})

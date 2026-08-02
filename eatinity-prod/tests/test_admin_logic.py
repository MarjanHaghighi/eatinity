import importlib.util
import os
import sys
import types
import unittest
from datetime import date
from decimal import Decimal
from pathlib import Path
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]


class FakeTable:
    def __init__(self, name):
        self.name = name

    def get_item(self, **kwargs):
        return {
            "Item": {
                "categoryId": kwargs.get("Key", {}).get("categoryId", ""),
                "active": True,
            }
        }


class FakeDynamo:
    products = []

    def Table(self, name):
        return FakeTable(name)

    def batch_get_item(self, **kwargs):
        return {"Responses": {"products": self.products}}


class FakeCognito:
    def __init__(self, user_sub="target-sub"):
        self.user_sub = user_sub

    def admin_get_user(self, **kwargs):
        return {
            "Username": kwargs["Username"],
            "UserAttributes": [{"Name": "sub", "Value": self.user_sub}],
        }


class FakeS3:
    def generate_presigned_post(self, **kwargs):
        return {"url": "https://example.com/upload", "fields": {"key": kwargs["Key"]}}


def load_module(name, relative_path, cognito=None):
    fake_dynamo = FakeDynamo()
    fake_cognito = cognito or FakeCognito()
    fake_stripe = types.SimpleNamespace(api_key=None)
    path = ROOT / relative_path

    with patch("boto3.resource", return_value=fake_dynamo), patch(
        "boto3.client", side_effect=lambda service, **kwargs: fake_cognito if service == "cognito-idp" else FakeS3() if service == "s3" else object()
    ), patch.dict(sys.modules, {"stripe": fake_stripe}):
        spec = importlib.util.spec_from_file_location(name, path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
    return module, fake_dynamo


class CheckoutSecurityTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.update({
            "STRIPE_SECRET_KEY": "test",
            "ORDERS_TABLE_NAME": "orders",
            "PRODUCTS_TABLE_NAME": "products",
        })
        cls.module, cls.dynamo = load_module(
            "checkout_test", "lambda/stripe_checkout/create_checkout_session.py"
        )

    def test_browser_price_and_name_are_ignored(self):
        self.dynamo.products = [{
            "id": "p001", "name": "Real Product", "price": "14.99",
            "available": True, "category": "main-food",
        }]
        items = self.module.load_products([
            {"id": "p001", "name": "Fake", "price": "0.01", "quantity": 2}
        ])
        self.assertEqual(items[0][0]["name"], "Real Product")
        self.assertEqual(items[0][0]["price"], "14.99")
        self.assertEqual(items[0][1], 2)

    def test_archived_product_is_rejected(self):
        self.dynamo.products = [{
            "id": "p001", "name": "Old Product", "price": "4.00",
            "available": True, "archived": True,
        }]
        with self.assertRaisesRegex(ValueError, "unavailable"):
            self.module.load_products([{"id": "p001", "quantity": 1}])

    def test_invalid_quantity_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "between 1 and 99"):
            self.module.load_products([{"id": "p001", "quantity": 100}])


class OrderWorkflowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.update({
            "ORDERS_TABLE_NAME": "orders",
            "AUDIT_TABLE_NAME": "audit",
            "SES_FROM_EMAIL": "orders@example.com",
        })
        cls.module, _ = load_module("orders_test", "lambda/admin_orders/admin_orders.py")

    def test_pickup_preparing_moves_to_ready(self):
        order = {"orderStatus": "Preparing", "deliveryMethod": "Pickup"}
        self.module.validate_transition(order, "Ready for Pickup", {"manager"})

    def test_pickup_cannot_move_to_delivery(self):
        order = {"orderStatus": "Preparing", "deliveryMethod": "Pickup"}
        with self.assertRaisesRegex(ValueError, "cannot move"):
            self.module.validate_transition(order, "Out for Delivery", {"manager"})

    def test_delivery_preparing_moves_out_for_delivery(self):
        order = {"orderStatus": "Preparing", "deliveryMethod": "Delivery"}
        self.module.validate_transition(order, "Out for Delivery", {"kitchen"})

    def test_kitchen_cannot_cancel(self):
        order = {"orderStatus": "Confirmed", "deliveryMethod": "Pickup"}
        with self.assertRaises(PermissionError):
            self.module.validate_transition(order, "Cancelled", {"kitchen"})


class ImageUploadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.update({
            "PRODUCTS_TABLE_NAME": "products",
            "CATEGORIES_TABLE_NAME": "categories",
            "AUDIT_TABLE_NAME": "audit",
            "IMAGE_BUCKET_NAME": "images",
        })
        cls.module, _ = load_module("menu_test", "lambda/admin_menu/admin_menu.py")

    def test_valid_image_gets_safe_unique_path(self):
        result = self.module.create_image_upload({
            "contentType": "image/webp", "fileSize": 1024,
            "category": "main-food",
            "fileName": "Fresh Chicken Bowl.WEBP",
        })
        self.assertRegex(
            result["imagePath"],
            r"^foods/main-food/Fresh%20Chicken%20Bowl-[a-f0-9]{12}\.webp$",
        )
        self.assertEqual(
            result["upload"]["fields"]["key"],
            result["imagePath"].replace("%20", " "),
        )

    def test_non_image_type_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "JPEG"):
            self.module.create_image_upload({
                "contentType": "text/html",
                "fileSize": 100,
                "category": "main-food",
            })

    def test_image_over_five_mb_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "5 MB"):
            self.module.create_image_upload({
                "contentType": "image/png", "fileSize": 5 * 1024 * 1024 + 1,
                "category": "main-food",
            })


class AuditLogTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["AUDIT_TABLE_NAME"] = "audit"
        cls.module, _ = load_module("audit_test", "lambda/admin_audit/admin_audit.py")

    def test_cursor_round_trip(self):
        key = {"scope": "ADMIN", "createdAt": "2026-07-17T12:00:00+00:00", "auditId": "a1"}
        self.assertEqual(self.module.decode_cursor(self.module.encode_cursor(key)), key)

    def test_invalid_cursor_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "Invalid audit cursor"):
            self.module.decode_cursor("not-valid-base64")

    def test_all_audit_writers_use_admin_scope(self):
        sources = [
            ROOT / "lambda/admin_orders/admin_orders.py",
            ROOT / "lambda/admin_menu/admin_menu.py",
            ROOT / "lambda/admin_users/admin_users.py",
        ]
        for source in sources:
            self.assertIn('"scope": "ADMIN"', source.read_text(encoding="utf-8"))


class SalesReportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ["ORDERS_TABLE_NAME"] = "orders"
        cls.module, _ = load_module("reports_test", "lambda/sales_reports/sales_reports.py")

    def test_report_totals(self):
        period, start, end, group = self.module.resolve_period({
            "period": "custom", "startDate": "2026-07-01", "endDate": "2026-07-31",
        })
        report = self.module.build_report([
            {
                "paidAt": "2026-07-17T15:00:00+00:00",
                "amountPaid": "22.60", "subtotalAmount": "20.00", "taxAmount": "2.60",
                "deliveryMethod": "Pickup",
                "items": [{"name": "Bowl", "price": "10.00", "quantity": 2}],
            },
            {
                "paidAt": "2026-07-18T16:00:00+00:00",
                "amountPaid": "11.30", "subtotalAmount": "10.00", "taxAmount": "1.30",
                "deliveryMethod": "Delivery",
                "items": [{"name": "Soup", "price": "10.00", "quantity": 1}],
            },
        ], period, start, end, group)
        self.assertEqual(report["summary"]["grossSales"], Decimal("33.90"))
        self.assertEqual(report["summary"]["taxCollected"], Decimal("3.90"))
        self.assertEqual(report["summary"]["paidOrderCount"], 2)
        self.assertEqual(report["summary"]["itemsSold"], 3)

    def test_custom_period_is_inclusive(self):
        _, start, end, _ = self.module.resolve_period({
            "period": "custom", "startDate": "2026-07-17", "endDate": "2026-07-17",
        })
        self.assertEqual(start.date(), date(2026, 7, 17))
        self.assertEqual(end.date(), date(2026, 7, 18))


class SuperAdminProtectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        os.environ.update({
            "USER_POOL_ID": "pool",
            "USERS_TABLE_NAME": "users",
            "AUDIT_TABLE_NAME": "audit",
        })

    def test_super_admin_cannot_disable_self(self):
        cognito = FakeCognito(user_sub="same-sub")
        module, _ = load_module("users_test", "lambda/admin_users/admin_users.py", cognito)
        with self.assertRaisesRegex(ValueError, "own super-admin"):
            module.ensure_not_self("owner@example.com", {"sub": "same-sub"}, "disable")


class IntegrationContractTests(unittest.TestCase):
    def test_webhook_retry_does_not_reset_order_status(self):
        source = (ROOT / "lambda/stripe_webhook/process_stripe_webhook.py").read_text(encoding="utf-8")
        self.assertNotIn("orderStatus = :pending", source)
        self.assertIn('if not order.get("snsSent")', source)
        self.assertIn('not order.get("emailSent")', source)

    def test_webhook_terraform_supplies_secrets_manager_arn(self):
        terraform = (
            ROOT.parent / "eatinity-iac/modules/application/lambda.tf"
        ).read_text(encoding="utf-8")
        webhook_start = terraform.index('resource "aws_lambda_function" "stripe_webhook"')
        webhook_end = terraform.index('resource "aws_lambda_function" "user_profile"')
        self.assertIn("STRIPE_SECRET_ARN", terraform[webhook_start:webhook_end])
        self.assertNotIn("STRIPE_SECRET_KEY", terraform[webhook_start:webhook_end])


if __name__ == "__main__":
    unittest.main()

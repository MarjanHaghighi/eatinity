import json
import os
import uuid
from datetime import datetime, timezone
from decimal import Decimal

import boto3


cognito = boto3.client("cognito-idp")
dynamodb = boto3.resource("dynamodb")
users_table = dynamodb.Table(os.environ["USERS_TABLE_NAME"])
audit_table = dynamodb.Table(os.environ["AUDIT_TABLE_NAME"])

USER_POOL_ID = os.environ["USER_POOL_ID"]
STAFF_GROUPS = {"super-admin", "admin", "manager", "kitchen"}
VIEW_GROUPS = {"super-admin", "admin"}


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


def get_groups_from_claims(claims):
    groups = claims.get("cognito:groups", [])
    if isinstance(groups, list):
        return set(groups)
    if not isinstance(groups, str):
        return set()
    return {group.strip().strip("'\"") for group in groups.strip("[]").split(",") if group.strip()}


def parse_body(event):
    try:
        return json.loads(event.get("body") or "{}")
    except json.JSONDecodeError as error:
        raise ValueError("Request body must be valid JSON.") from error


def attributes_to_dict(attributes):
    return {item["Name"]: item.get("Value", "") for item in attributes or []}


def list_all_cognito_users():
    users = []
    token = None
    while True:
        arguments = {"UserPoolId": USER_POOL_ID, "Limit": 60}
        if token:
            arguments["PaginationToken"] = token
        result = cognito.list_users(**arguments)
        users.extend(result.get("Users", []))
        token = result.get("PaginationToken")
        if not token:
            return users


def list_all_profiles():
    result = users_table.scan()
    items = result.get("Items", [])
    while "LastEvaluatedKey" in result:
        result = users_table.scan(ExclusiveStartKey=result["LastEvaluatedKey"])
        items.extend(result.get("Items", []))
    return {item["userId"]: item for item in items}


def get_user_groups(username):
    result = cognito.admin_list_groups_for_user(UserPoolId=USER_POOL_ID, Username=username)
    return [group["GroupName"] for group in result.get("Groups", [])]


def build_user(account, profiles):
    attributes = attributes_to_dict(account.get("Attributes"))
    user_id = attributes.get("sub", "")
    profile = profiles.get(user_id, {})
    groups = get_user_groups(account["Username"])
    return {
        "username": account["Username"],
        "userId": user_id,
        "email": attributes.get("email", profile.get("email", "")),
        "name": attributes.get("name", profile.get("name", "")),
        "phone": profile.get("phone", ""),
        "groups": groups,
        "accountType": "staff" if set(groups).intersection(STAFF_GROUPS) else "customer",
        "enabled": account.get("Enabled", False),
        "status": account.get("UserStatus", "UNKNOWN"),
        "createdAt": account.get("UserCreateDate"),
        "lastModifiedAt": account.get("UserLastModifiedDate"),
        "jobTitle": profile.get("jobTitle", ""),
    }


def list_users(query):
    account_type = str(query.get("accountType", "")).lower()
    search = str(query.get("search", "")).lower().strip()
    profiles = list_all_profiles()
    users = [build_user(account, profiles) for account in list_all_cognito_users()]
    if account_type:
        users = [user for user in users if user["accountType"] == account_type]
    if search:
        users = [user for user in users if search in " ".join([
            user["username"], user["userId"], user["email"], user["name"], user["phone"]
        ]).lower()]
    users.sort(key=lambda user: (user["accountType"] != "staff", user["name"], user["email"]))
    return users


def write_audit(action, username, claims, old_value, new_value, request_id):
    now = datetime.now(timezone.utc).isoformat()
    audit_table.put_item(Item={
        "auditId": str(uuid.uuid4()),
        "scope": "ADMIN",
        "entityType": "USER",
        "entityId": username,
        "action": action,
        "actorUserId": claims.get("sub", "unknown"),
        "actorEmail": claims.get("email", ""),
        "oldValue": old_value,
        "newValue": new_value,
        "createdAt": now,
        "requestId": request_id,
    })


def require_super_admin(groups):
    if "super-admin" not in groups:
        raise PermissionError("Only a super-admin can manage staff accounts and groups.")


def get_account(username):
    return cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=username)


def ensure_not_self(username, claims, action):
    account = get_account(username)
    attributes = attributes_to_dict(account.get("UserAttributes"))
    if attributes.get("sub") == claims.get("sub"):
        raise ValueError(f"You cannot {action} your own super-admin account.")
    return account


def active_super_admin_count():
    result = cognito.list_users_in_group(UserPoolId=USER_POOL_ID, GroupName="super-admin", Limit=60)
    return sum(1 for user in result.get("Users", []) if user.get("Enabled"))


def protect_final_super_admin(username):
    if "super-admin" in get_user_groups(username) and active_super_admin_count() <= 1:
        raise ValueError("The final active super-admin cannot be disabled or demoted.")


def create_staff(body, claims, request_id):
    email = str(body.get("email", "")).strip().lower()
    name = str(body.get("name", "")).strip()
    role = str(body.get("role", "")).strip()
    if not email or "@" not in email:
        raise ValueError("A valid email is required.")
    if not name:
        raise ValueError("name is required.")
    if role not in STAFF_GROUPS:
        raise ValueError("Select a valid staff role.")

    result = cognito.admin_create_user(
        UserPoolId=USER_POOL_ID,
        Username=email,
        UserAttributes=[
            {"Name": "email", "Value": email},
            {"Name": "email_verified", "Value": "true"},
            {"Name": "name", "Value": name},
        ],
        DesiredDeliveryMediums=["EMAIL"],
    )
    cognito.admin_add_user_to_group(UserPoolId=USER_POOL_ID, Username=email, GroupName=role)
    attributes = attributes_to_dict(result["User"].get("Attributes"))
    now = datetime.now(timezone.utc).isoformat()
    users_table.put_item(Item={
        "userId": attributes["sub"], "email": email, "name": name,
        "phone": "", "accountType": "staff", "jobTitle": str(body.get("jobTitle", "")).strip(),
        "isActive": True, "createdAt": now, "updatedAt": now,
    })
    write_audit("STAFF_CREATED", email, claims, {}, {"role": role}, request_id)
    return {"username": email, "userId": attributes["sub"], "email": email, "name": name, "groups": [role], "accountType": "staff", "enabled": True, "status": result["User"].get("UserStatus")}


def change_role(username, role, claims, request_id):
    if role not in STAFF_GROUPS:
        raise ValueError("Select a valid staff role.")
    ensure_not_self(username, claims, "change the role of")
    old_groups = get_user_groups(username)
    if "super-admin" in old_groups and role != "super-admin":
        protect_final_super_admin(username)
    for group in set(old_groups).intersection(STAFF_GROUPS):
        if group != role:
            cognito.admin_remove_user_from_group(UserPoolId=USER_POOL_ID, Username=username, GroupName=group)
    if role not in old_groups:
        cognito.admin_add_user_to_group(UserPoolId=USER_POOL_ID, Username=username, GroupName=role)
    write_audit("STAFF_ROLE_CHANGED", username, claims, {"groups": old_groups}, {"role": role}, request_id)
    return get_user_groups(username)


def set_enabled(username, enabled, claims, request_id):
    if not enabled:
        ensure_not_self(username, claims, "disable")
        protect_final_super_admin(username)
        cognito.admin_disable_user(UserPoolId=USER_POOL_ID, Username=username)
    else:
        cognito.admin_enable_user(UserPoolId=USER_POOL_ID, Username=username)
    account = get_account(username)
    attributes = attributes_to_dict(account.get("UserAttributes"))
    if attributes.get("sub"):
        users_table.update_item(
            Key={"userId": attributes["sub"]},
            UpdateExpression="SET isActive = :active, updatedAt = :now",
            ExpressionAttributeValues={":active": enabled, ":now": datetime.now(timezone.utc).isoformat()},
        )
    write_audit("USER_ENABLED" if enabled else "USER_DISABLED", username, claims, {}, {"enabled": enabled}, request_id)


def lambda_handler(event, context):
    try:
        claims = get_claims(event)
        groups = get_groups_from_claims(claims)
        if not groups.intersection(VIEW_GROUPS):
            return response(403, {"error": "You do not have permission to view users."})

        method = event.get("requestContext", {}).get("http", {}).get("method", "")
        path = event.get("rawPath", "")
        params = event.get("pathParameters") or {}
        username = params.get("username")
        request_id = getattr(context, "aws_request_id", "")

        if path == "/admin/users" and method == "GET":
            return response(200, {"users": list_users(event.get("queryStringParameters") or {})})

        require_super_admin(groups)
        if path == "/admin/staff" and method == "POST":
            return response(201, {"user": create_staff(parse_body(event), claims, request_id)})
        if username and path.endswith("/role") and method == "PATCH":
            role = str(parse_body(event).get("role", "")).strip()
            return response(200, {"groups": change_role(username, role, claims, request_id)})
        if username and path.endswith("/disable") and method == "POST":
            set_enabled(username, False, claims, request_id)
            return response(200, {"enabled": False})
        if username and path.endswith("/enable") and method == "POST":
            set_enabled(username, True, claims, request_id)
            return response(200, {"enabled": True})
        if username and path.endswith("/reset-password") and method == "POST":
            ensure_not_self(username, claims, "reset the password for")
            cognito.admin_reset_user_password(UserPoolId=USER_POOL_ID, Username=username)
            write_audit("PASSWORD_RESET_REQUESTED", username, claims, {}, {}, request_id)
            return response(200, {"message": "Password reset requested."})
        return response(404, {"error": "Admin user route not found."})
    except PermissionError as error:
        return response(403, {"error": str(error)})
    except ValueError as error:
        return response(400, {"error": str(error)})
    except cognito.exceptions.UserNotFoundException:
        return response(404, {"error": "User not found."})
    except cognito.exceptions.UsernameExistsException:
        return response(409, {"error": "A Cognito account already exists for this email."})
    except Exception as error:
        print("Admin users error:", str(error))
        return response(500, {"error": "Could not process the admin user request."})

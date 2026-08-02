# Eatinity Admin Dashboard User Guide

This guide describes the locally implemented Version 1 Admin Dashboard. Features that communicate with AWS become operational only after a separately authorized deployment.

## Signing in and opening Admin

1. Sign in through the normal Eatinity account page.
2. Cognito includes the staff groups in the signed login token.
3. The **Admin** navigation item appears only for authorized staff.
4. Kitchen staff are taken directly to **Orders**. Other staff open the Dashboard.

If a staff member's group changes while they are signed in, they should sign out and sign back in to receive a new token.

## Roles

### Super Admin

- Full Dashboard, Orders, Menu, Users & Staff, Reports, and Audit Log access
- Creates staff and changes staff groups
- Enables/disables accounts and requests password resets
- Can review before/after audit values

A super-admin cannot disable or demote their own account, and the final active super-admin is protected.

### Admin

- Dashboard, Orders, Menu, Reports, and read-only Users & Staff access
- Cannot create staff or change Cognito groups
- Cannot view the Audit Log

### Manager

- Dashboard, Orders, Menu, and Reports access
- Cannot access Users & Staff or the Audit Log

### Kitchen

- Orders only
- Can perform preparation transitions
- Cannot cancel, complete, or manage menu/users/reports

## Dashboard

The Dashboard shows:

- Today's gross sales and paid-order count
- Pending/confirmed, preparing, and ready/delivery order counts
- Unavailable-product count
- Recent orders
- Today's best-selling products

Each service loads independently. A warning identifies any section whose API could not load.

## Order Management

Use search and filters to find an order by ID, customer, email, phone, payment status, delivery method, or order status.

### Pickup workflow

`Pending → Confirmed → Preparing → Ready for Pickup → Picked Up → Completed`

Changing a pickup order to **Ready for Pickup** sends the customer email once. The order records whether it succeeded or failed.

### Delivery workflow

`Pending → Confirmed → Preparing → Out for Delivery → Delivered`

### Safety

- Confirm the customer and order ID before changing status.
- Status changes are recorded with actor and timestamp.
- Concurrent changes are rejected so one staff member does not overwrite another.
- Cancellation is unavailable to kitchen users.

## Menu Management

### Products

- Add or edit name, description, category, price, display order, ingredients, and allergens.
- Toggle **Available** to temporarily hide a product from ordering.
- Toggle **Featured** for future featured-menu presentation.
- Upload JPEG, PNG, WebP, or AVIF images up to 5 MB.
- Use **Archive** instead of deleting products.

Archived products disappear from the customer menu and cannot be purchased, while historical orders remain intact.

### Categories

- Category IDs use lowercase letters, numbers, and hyphens, such as `main-food`.
- Display order determines category ordering.
- Inactive categories cannot be assigned to new products.

## Users & Staff

### Customers

Admins and super-admins can search and review Cognito account status and DynamoDB profile information.

### Staff

Only a super-admin can:

- Send a staff invitation
- Assign `super-admin`, `admin`, `manager`, or `kitchen`
- Change a role
- Enable or disable an account
- Request a password reset

Disabling is preferred to deletion because it preserves audit and historical ownership information.

## Sales Reports

Available periods:

- Today: hourly
- Daily: last seven days
- Weekly: last eight weeks
- Monthly: last twelve months
- Custom: up to 366 days

Reports include gross sales, subtotal, tax, paid orders, average order value, items sold, product performance, and pickup/delivery totals. Only paid orders are counted, using `America/Toronto` business dates.

Use **Export CSV** to save the currently displayed report.

## Audit Log

Only super-admins can open the Audit Log. Filter by entity type, exact action, actor email, entity ID, or user ID. Expand an entry to compare before and after values.

Audit records are operational history. They are different from current product, category, order, or user data.

## Checkout security

- The browser submits only product IDs and quantities.
- DynamoDB supplies the authoritative product names, prices, categories, and availability.
- Guest checkout cannot claim a Cognito user ID.
- Authenticated checkout uses the verified Cognito subject claim.

The cart display is an estimate. If a product price changes before payment, Stripe Checkout uses the current DynamoDB price.

## Troubleshooting

- **Admin menu missing:** sign out/in and confirm Cognito group membership.
- **Forbidden response:** the backend role does not permit the action.
- **Image upload failed:** verify file type, size, S3 CORS, Lambda S3 permission, and image delivery policy.
- **Ready email failed:** check the order notification error and SES configuration.
- **No sales shown:** confirm the order is `Paid` and has `paidAt`.
- **Staff invitation failed:** check Cognito email configuration and `LabRole` permissions.

No live AWS action described here has been executed as part of the local implementation work.

export const ADMIN_PERMISSIONS = {
  VIEW_DASHBOARD: "view:dashboard",
  MANAGE_ORDERS: "manage:orders",
  MANAGE_MENU: "manage:menu",
  MANAGE_USERS: "manage:users",
  MANAGE_STAFF: "manage:staff",
  VIEW_REPORTS: "view:reports",
  VIEW_AUDIT_LOG: "view:audit-log",
};

export const ROLE_PERMISSIONS = {
  "super-admin": Object.values(ADMIN_PERMISSIONS),
  admin: [
    ADMIN_PERMISSIONS.VIEW_DASHBOARD,
    ADMIN_PERMISSIONS.MANAGE_ORDERS,
    ADMIN_PERMISSIONS.MANAGE_MENU,
    ADMIN_PERMISSIONS.MANAGE_USERS,
    ADMIN_PERMISSIONS.VIEW_REPORTS,
  ],
  manager: [
    ADMIN_PERMISSIONS.VIEW_DASHBOARD,
    ADMIN_PERMISSIONS.MANAGE_ORDERS,
    ADMIN_PERMISSIONS.MANAGE_MENU,
    ADMIN_PERMISSIONS.VIEW_REPORTS,
  ],
  kitchen: [ADMIN_PERMISSIONS.MANAGE_ORDERS],
};

export const ADMIN_NAV_ITEMS = [
  {
    label: "Dashboard",
    path: "/admin",
    permission: ADMIN_PERMISSIONS.VIEW_DASHBOARD,
  },
  {
    label: "Orders",
    path: "/admin/orders",
    permission: ADMIN_PERMISSIONS.MANAGE_ORDERS,
  },
  {
    label: "Food Management",
    path: "/admin/menu",
    permission: ADMIN_PERMISSIONS.MANAGE_MENU,
  },
  {
    label: "Users & Staff",
    path: "/admin/users",
    permission: ADMIN_PERMISSIONS.MANAGE_USERS,
  },
  {
    label: "Sales Reports",
    path: "/admin/reports",
    permission: ADMIN_PERMISSIONS.VIEW_REPORTS,
  },
  {
    label: "Audit Log",
    path: "/admin/audit-log",
    permission: ADMIN_PERMISSIONS.VIEW_AUDIT_LOG,
  },
];

export function hasPermission(groups = [], permission) {
  return groups.some((group) =>
    (ROLE_PERMISSIONS[group] || []).includes(permission)
  );
}

export function getPrimaryAdminRole(groups = []) {
  return ["super-admin", "admin", "manager", "kitchen"].find((role) =>
    groups.includes(role)
  );
}

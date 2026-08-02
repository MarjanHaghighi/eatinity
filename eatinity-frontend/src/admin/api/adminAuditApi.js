import { adminRequest } from "./adminApi";

export async function fetchAdminAuditLog(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  const suffix = query.toString() ? `?${query}` : "";
  return adminRequest(`/admin/audit-log${suffix}`);
}

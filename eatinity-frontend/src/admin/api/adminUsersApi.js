import { adminRequest } from "./adminApi";

export async function fetchAdminUsers(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  const suffix = query.toString() ? `?${query}` : "";
  return (await adminRequest(`/admin/users${suffix}`)).users || [];
}

export async function createAdminStaff(staff) {
  return (await adminRequest("/admin/staff", {
    method: "POST",
    body: JSON.stringify(staff),
  })).user;
}

export async function changeAdminStaffRole(username, role) {
  return (await adminRequest(`/admin/staff/${encodeURIComponent(username)}/role`, {
    method: "PATCH",
    body: JSON.stringify({ role }),
  })).groups;
}

export async function setAdminUserEnabled(username, enabled) {
  return adminRequest(
    `/admin/staff/${encodeURIComponent(username)}/${enabled ? "enable" : "disable"}`,
    { method: "POST" }
  );
}

export async function resetAdminUserPassword(username) {
  return adminRequest(`/admin/staff/${encodeURIComponent(username)}/reset-password`, {
    method: "POST",
  });
}

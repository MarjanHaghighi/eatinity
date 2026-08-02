import { adminRequest } from "./adminApi";

export async function fetchAdminOrders(filters = {}) {
  const query = new URLSearchParams();
  Object.entries(filters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  const suffix = query.toString() ? `?${query}` : "";
  return (await adminRequest(`/admin/orders${suffix}`)).orders || [];
}

export async function fetchAdminOrder(orderId) {
  return (await adminRequest(`/admin/orders/${encodeURIComponent(orderId)}`)).order;
}

export async function updateAdminOrderStatus(orderId, orderStatus) {
  return (await adminRequest(`/admin/orders/${encodeURIComponent(orderId)}/status`, {
    method: "PATCH",
    body: JSON.stringify({ orderStatus }),
  })).order;
}

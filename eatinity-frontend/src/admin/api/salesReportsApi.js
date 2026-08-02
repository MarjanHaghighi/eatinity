import { adminRequest } from "./adminApi";

export async function fetchSalesReport(parameters = {}) {
  const query = new URLSearchParams();
  Object.entries(parameters).forEach(([key, value]) => {
    if (value) query.set(key, value);
  });
  const suffix = query.toString() ? `?${query}` : "";
  return (await adminRequest(`/admin/reports/sales${suffix}`)).report;
}

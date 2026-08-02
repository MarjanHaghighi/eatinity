import { getIdToken } from "../../auth/authService";
import { API_BASE_URL } from "../../config";

export async function adminRequest(path, options = {}) {
  const token = await getIdToken();
  if (!token) throw new Error("Your session has expired. Please sign in again.");

  const response = await fetch(`${API_BASE_URL}${path}`, {
    ...options,
    headers: {
      ...(options.body ? { "Content-Type": "application/json" } : {}),
      ...options.headers,
      Authorization: `Bearer ${token}`,
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || data.message || "Admin request failed.");
  return data;
}

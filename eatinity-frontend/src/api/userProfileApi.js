import { getIdToken } from "../auth/authService";

import { API_BASE_URL } from "../config";
const USER_PROFILE_API_URL = `${API_BASE_URL}/user-profile`;
const USER_ORDERS_API_URL = `${API_BASE_URL}/user-orders`;

export async function fetchUserProfile() {
  const token = await getIdToken();

  if (!token) {
    return null;
  }

  const response = await fetch(USER_PROFILE_API_URL, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(data.error || data.message || "Unable to fetch user profile.");
  }

  return data.profile;
}

export async function updateUserProfile(profile) {
  const token = await getIdToken();

  if (!token) {
    throw new Error("You must be signed in to update your profile.");
  }

  const response = await fetch(USER_PROFILE_API_URL, {
    method: "PUT",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${token}`,
    },
    body: JSON.stringify(profile),
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(data.error || data.message || "Unable to update user profile.");
  }

  return data.profile;
}

export async function fetchUserOrders() {
  const token = await getIdToken();

  if (!token) {
    return [];
  }

  const response = await fetch(USER_ORDERS_API_URL, {
    method: "GET",
    headers: {
      Authorization: `Bearer ${token}`,
    },
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(data.error || data.message || "Unable to fetch your orders.");
  }

  return data.orders || [];
}

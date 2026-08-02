const runtimeConfig = window.__EATINITY_CONFIG__ || {};

export const API_BASE_URL =
  runtimeConfig.apiBaseUrl || import.meta.env.VITE_API_BASE_URL || "";

export const API_URL = `${API_BASE_URL}/products`;

export const IMAGE_BASE_URL =
  runtimeConfig.imageBaseUrl || import.meta.env.VITE_IMAGE_BASE_URL || "";
  

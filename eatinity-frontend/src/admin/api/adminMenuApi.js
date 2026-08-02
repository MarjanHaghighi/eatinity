import { adminRequest } from "./adminApi";

export const fetchAdminProducts = async () => (await adminRequest("/admin/products")).products || [];
export const fetchAdminCategories = async () => (await adminRequest("/admin/categories")).categories || [];

export async function createAdminProduct(product) {
  return (await adminRequest("/admin/products", { method: "POST", body: JSON.stringify(product) })).product;
}

export async function updateAdminProduct(productId, product) {
  return (await adminRequest(`/admin/products/${encodeURIComponent(productId)}`, { method: "PUT", body: JSON.stringify(product) })).product;
}

export async function setAdminProductAvailability(productId, available) {
  return (await adminRequest(`/admin/products/${encodeURIComponent(productId)}/availability`, { method: "PATCH", body: JSON.stringify({ available }) })).product;
}

export async function archiveAdminProduct(productId) {
  return (await adminRequest(`/admin/products/${encodeURIComponent(productId)}`, { method: "DELETE" })).product;
}

export async function restoreAdminProduct(productId) {
  return (await adminRequest(`/admin/products/${encodeURIComponent(productId)}/restore`, { method: "PATCH" })).product;
}

export async function createAdminCategory(category) {
  return (await adminRequest("/admin/categories", { method: "POST", body: JSON.stringify(category) })).category;
}

export async function updateAdminCategory(categoryId, category) {
  return (await adminRequest(`/admin/categories/${encodeURIComponent(categoryId)}`, { method: "PUT", body: JSON.stringify(category) })).category;
}

export async function uploadAdminProductImage(file, category) {
  const data = await adminRequest("/admin/uploads/product-image", {
    method: "POST",
    body: JSON.stringify({
      contentType: file.type,
      fileSize: file.size,
      fileName: file.name,
      category,
    }),
  });
  const form = new FormData();
  Object.entries(data.upload.fields).forEach(([key, value]) => form.append(key, value));
  form.append("file", file);

  const response = await fetch(data.upload.url, { method: "POST", body: form });
  if (!response.ok) {
    throw new Error("The image could not be uploaded to S3.");
  }
  return data.imagePath;
}

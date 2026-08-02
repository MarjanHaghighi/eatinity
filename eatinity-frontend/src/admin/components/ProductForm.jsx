import { useState } from "react";
import { uploadAdminProductImage } from "../api/adminMenuApi";

const EMPTY_PRODUCT = { name: "", description: "", category: "", price: "", imagePath: "", displayOrder: 0, available: true, featured: false, ingredients: "", allergens: "" };
const listToText = (value) => Array.isArray(value) ? value.join(", ") : value || "";
const textToList = (value) => value.split(",").map((item) => item.trim()).filter(Boolean);
const nextAvailableOrder = (products, category) => {
  const used = new Set(
    products
      .filter((item) => item.category === category && !item.archived)
      .map((item) => Number(item.displayOrder))
  );
  let next = 10;
  while (used.has(next)) next += 10;
  return next;
};

function ProductForm({ categories, products, product, saving, onCancel, onSave }) {
  const [form, setForm] = useState(() => product ? {
    ...EMPTY_PRODUCT,
    ...product,
    ingredients: listToText(product.ingredients),
    allergens: listToText(product.allergens),
  } : EMPTY_PRODUCT);
  const [uploading, setUploading] = useState(false);
  const [uploadError, setUploadError] = useState("");
  const suggestedOrder = nextAvailableOrder(products, form.category);

  const updateField = ({ target }) => setForm((current) => ({ ...current, [target.name]: target.type === "checkbox" ? target.checked : target.value }));
  const updateCategory = ({ target }) => {
    const category = target.value;
    setForm((current) => ({
      ...current,
      category,
      ...(!product ? { displayOrder: nextAvailableOrder(products, category) } : {}),
    }));
  };
  const submit = (event) => {
    event.preventDefault();
    onSave({ ...form, price: Number(form.price), displayOrder: Number(form.displayOrder), ingredients: textToList(form.ingredients), allergens: textToList(form.allergens) });
  };

  const uploadImage = async (event) => {
    const file = event.target.files?.[0];
    if (!file) return;
    if (!form.category) {
      setUploadError("Select a category before uploading an image.");
      event.target.value = "";
      return;
    }
    setUploading(true);
    setUploadError("");
    try {
      const imagePath = await uploadAdminProductImage(file, form.category);
      setForm((current) => ({ ...current, imagePath }));
    } catch (error) {
      setUploadError(error.message);
    } finally {
      setUploading(false);
      event.target.value = "";
    }
  };

  return (
    <form className="admin-form" onSubmit={submit}>
      <div className="admin-form-header"><h2>{product ? "Edit Menu Item" : "Add Menu Item"}</h2><button className="admin-button secondary" type="button" onClick={onCancel}>Close</button></div>
      <div className="admin-form-grid">
        <label>Name<input name="name" required value={form.name} onChange={updateField} /></label>
        <label>Category<select name="category" required value={form.category} onChange={updateCategory}><option value="">Select category</option>{categories.filter((item) => item.active !== false).map((item) => <option key={item.categoryId} value={item.categoryId}>{item.name}</option>)}</select></label>
        <label>Price (CAD)<input name="price" type="number" min="0.01" step="0.01" required value={form.price} onChange={updateField} /></label>
        <label>Display order<input name="displayOrder" type="number" min="0" step="1" value={form.displayOrder} onChange={updateField} /><small>{form.category ? `Suggested next available order in this category: ${suggestedOrder}.` : "Select a category to calculate the next available order."} Lower numbers appear first.</small></label>
        <label className="admin-form-wide">Description<textarea name="description" rows="3" value={form.description} onChange={updateField} /></label>
        <label className="admin-form-wide admin-image-upload">Upload a new image<input type="file" accept="image/jpeg,image/png,image/webp,image/avif" disabled={uploading} onChange={uploadImage} /><small>{uploading ? "Uploading image..." : "JPEG, PNG, WebP or AVIF · maximum 5 MB"}</small>{uploadError && <span>{uploadError}</span>}</label>
        {form.imagePath && <p className="admin-form-wide admin-form-help">Image ready: {form.imagePath}</p>}
        <label>Ingredients<input name="ingredients" placeholder="Chicken, rice, vegetables" value={form.ingredients} onChange={updateField} /></label>
        <label>Allergens<input name="allergens" placeholder="Dairy, nuts" value={form.allergens} onChange={updateField} /></label>
      </div>
      <div className="admin-checkbox-row"><label><input name="available" type="checkbox" checked={form.available} onChange={updateField} /> Available</label><label><input name="featured" type="checkbox" checked={form.featured} onChange={updateField} /> Featured</label></div>
      <button className="admin-button primary" disabled={saving || uploading} type="submit">{saving ? "Saving..." : "Save Menu Item"}</button>
    </form>
  );
}

export default ProductForm;

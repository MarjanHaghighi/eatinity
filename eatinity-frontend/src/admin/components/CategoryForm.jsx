import { useState } from "react";

const EMPTY_CATEGORY = { categoryId: "", name: "", description: "", displayOrder: 0, active: true };

const nextAvailableOrder = (items) => {
  const used = new Set(items.map((item) => Number(item.displayOrder)));
  let next = 10;
  while (used.has(next)) next += 10;
  return next;
};

function CategoryForm({ categories, category, saving, onCancel, onSave }) {
  const suggestedOrder = nextAvailableOrder(categories);
  const [form, setForm] = useState(() => category ? { ...EMPTY_CATEGORY, ...category } : { ...EMPTY_CATEGORY, displayOrder: suggestedOrder });
  const updateField = ({ target }) => setForm((current) => ({ ...current, [target.name]: target.type === "checkbox" ? target.checked : target.value }));
  const submit = (event) => { event.preventDefault(); onSave({ ...form, categoryId: form.categoryId.toLowerCase(), displayOrder: Number(form.displayOrder) }); };

  return (
    <form className="admin-form" onSubmit={submit}>
      <div className="admin-form-header"><h2>{category ? "Edit Category" : "Add Category"}</h2><button className="admin-button secondary" type="button" onClick={onCancel}>Close</button></div>
      <div className="admin-form-grid">
        <label>Category ID<input name="categoryId" pattern="[a-z0-9]+(?:-[a-z0-9]+)*" disabled={Boolean(category)} required value={form.categoryId} onChange={updateField} /></label>
        <label>Name<input name="name" required value={form.name} onChange={updateField} /></label>
        <label>Display order<input name="displayOrder" type="number" min="0" step="1" value={form.displayOrder} onChange={updateField} /><small>Suggested next available order: {suggestedOrder}. Lower numbers appear first.</small></label>
        <label className="admin-checkbox-field"><input name="active" type="checkbox" checked={form.active} onChange={updateField} /> Active</label>
        <label className="admin-form-wide">Description<textarea name="description" rows="3" value={form.description} onChange={updateField} /></label>
      </div>
      <button className="admin-button primary" disabled={saving} type="submit">{saving ? "Saving..." : "Save Category"}</button>
    </form>
  );
}

export default CategoryForm;

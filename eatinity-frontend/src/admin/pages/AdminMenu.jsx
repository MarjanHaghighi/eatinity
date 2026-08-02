import { useEffect, useMemo, useState } from "react";
import {
  archiveAdminProduct, createAdminCategory, createAdminProduct,
  fetchAdminCategories, fetchAdminProducts, setAdminProductAvailability,
  restoreAdminProduct, updateAdminCategory, updateAdminProduct,
} from "../api/adminMenuApi";
import CategoryForm from "../components/CategoryForm";
import ProductForm from "../components/ProductForm";

function AdminMenu() {
  const [tab, setTab] = useState("products");
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);
  const [search, setSearch] = useState("");
  const [categoryFilter, setCategoryFilter] = useState("all");
  const [showArchived, setShowArchived] = useState(true);
  const [editingProduct, setEditingProduct] = useState(undefined);
  const [editingCategory, setEditingCategory] = useState(undefined);
  const [formType, setFormType] = useState(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let active = true;
    Promise.all([fetchAdminProducts(), fetchAdminCategories()])
      .then(([productData, categoryData]) => {
        if (active) { setProducts(productData); setCategories(categoryData); }
      })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const filteredProducts = useMemo(() => {
    const term = search.trim().toLowerCase();
    return products.filter((product) =>
      (!term || product.name?.toLowerCase().includes(term) || product.id?.toLowerCase().includes(term)) &&
      (categoryFilter === "all" || product.category === categoryFilter) &&
      (showArchived || !product.archived)
    );
  }, [products, search, categoryFilter, showArchived]);

  const runAction = async (action, successMessage) => {
    setError(""); setMessage(""); setSaving(true);
    try {
      await action();
      const [productData, categoryData] = await Promise.all([fetchAdminProducts(), fetchAdminCategories()]);
      setProducts(productData); setCategories(categoryData); setFormType(null);
      setEditingProduct(undefined); setEditingCategory(undefined); setMessage(successMessage);
    } catch (actionError) { setError(actionError.message); }
    finally { setSaving(false); }
  };

  const saveProduct = (product) => runAction(
    () => editingProduct ? updateAdminProduct(editingProduct.id, product) : createAdminProduct(product),
    editingProduct ? "Menu item updated." : "Menu item created."
  );
  const saveCategory = (category) => runAction(
    () => editingCategory ? updateAdminCategory(editingCategory.categoryId, category) : createAdminCategory(category),
    editingCategory ? "Category updated." : "Category created."
  );
  const toggleAvailability = (product) => runAction(
    () => setAdminProductAvailability(product.id, !product.available),
    `${product.name} is now ${product.available ? "unavailable" : "available"}.`
  );
  const archiveProduct = (product) => {
    if (window.confirm(`Archive ${product.name}? It will disappear from the customer menu.`)) {
      runAction(() => archiveAdminProduct(product.id), `${product.name} was archived.`);
    }
  };
  const restoreProduct = (product) => {
    if (window.confirm(`Restore ${product.name} to the customer menu?`)) {
      runAction(() => restoreAdminProduct(product.id), `${product.name} was restored and is available.`);
    }
  };
  const openNewForm = () => {
    if (tab === "products") { setEditingProduct(null); setFormType("product"); }
    else { setEditingCategory(null); setFormType("category"); }
  };
  const selectTab = (nextTab) => {
    setTab(nextTab);
    setFormType(null);
    setEditingProduct(undefined);
    setEditingCategory(undefined);
    setError("");
    setMessage("");
  };

  return (
    <section className="admin-dashboard">
      <div className="admin-page-title">
        <div><p className="admin-eyebrow">Eatinity Administration</p><h1>Food Management</h1></div>
        <button className="admin-button primary" onClick={openNewForm}>Add {tab === "products" ? "Menu Item" : "Category"}</button>
      </div>
      {error && <div className="admin-alert error">{error}</div>}
      {message && <div className="admin-alert success">{message}</div>}
      <div className="admin-tabs">
        <button className={tab === "products" ? "active" : ""} onClick={() => selectTab("products")}>Menu Items</button>
        <button className={tab === "categories" ? "active" : ""} onClick={() => selectTab("categories")}>Categories</button>
      </div>

      {formType === "product" && <ProductForm key={editingProduct?.id || "new-product"} categories={categories} products={products} product={editingProduct} saving={saving} onCancel={() => setFormType(null)} onSave={saveProduct} />}
      {formType === "category" && <CategoryForm key={editingCategory?.categoryId || "new-category"} categories={categories} category={editingCategory} saving={saving} onCancel={() => setFormType(null)} onSave={saveCategory} />}

      {loading ? <p>Loading menu...</p> : tab === "products" ? (
        <>
          <div className="admin-filters">
            <input aria-label="Search products" placeholder="Search products" value={search} onChange={(event) => setSearch(event.target.value)} />
            <select aria-label="Filter by category" value={categoryFilter} onChange={(event) => setCategoryFilter(event.target.value)}>
              <option value="all">All categories</option>
              {categories.map((category) => <option key={category.categoryId} value={category.categoryId}>{category.name}</option>)}
            </select>
            <label><input type="checkbox" checked={showArchived} onChange={(event) => setShowArchived(event.target.checked)} /> Show archived</label>
          </div>
          <div className="admin-table-wrap"><table className="admin-table">
            <thead><tr><th>Menu Item</th><th>Category</th><th>Price</th><th>Status</th><th>Order</th><th>Actions</th></tr></thead>
            <tbody>
              {filteredProducts.map((product) => <tr key={product.id}>
                <td><strong>{product.name}</strong><small>{product.id}</small></td><td>{product.category}</td><td>${Number(product.price).toFixed(2)}</td>
                <td><span className={`admin-status ${product.archived ? "archived" : product.available ? "available" : "unavailable"}`}>{product.archived ? "Archived" : product.available ? "Available" : "Unavailable"}</span></td>
                <td>{product.displayOrder ?? 0}</td><td className="admin-actions">
                  <button onClick={() => { setEditingProduct(product); setFormType("product"); }}>Edit</button>
                  {!product.archived && <button onClick={() => toggleAvailability(product)}>{product.available ? "Disable" : "Enable"}</button>}
                  {!product.archived && <button className="danger" onClick={() => archiveProduct(product)}>Archive</button>}
                  {product.archived && <button onClick={() => restoreProduct(product)}>Restore</button>}
                </td>
              </tr>)}
              {!filteredProducts.length && <tr><td colSpan="6">No menu items match these filters.</td></tr>}
            </tbody>
          </table></div>
        </>
      ) : (
        <div className="admin-table-wrap"><table className="admin-table">
          <thead><tr><th>Category</th><th>ID</th><th>Order</th><th>Status</th><th>Actions</th></tr></thead>
          <tbody>
            {categories.map((category) => <tr key={category.categoryId}><td><strong>{category.name}</strong></td><td>{category.categoryId}</td><td>{category.displayOrder}</td><td><span className={`admin-status ${category.active ? "available" : "unavailable"}`}>{category.active ? "Active" : "Inactive"}</span></td><td className="admin-actions"><button onClick={() => { setEditingCategory(category); setFormType("category"); }}>Edit</button></td></tr>)}
            {!categories.length && <tr><td colSpan="5">No categories have been created yet.</td></tr>}
          </tbody>
        </table></div>
      )}
    </section>
  );
}

export default AdminMenu;

import { useEffect, useState } from "react";
import { useAuth } from "../../auth/AuthContext";
import { fetchAdminOrder, fetchAdminOrders, updateAdminOrderStatus } from "../api/adminOrdersApi";
import AdminOrderDetails from "../components/AdminOrderDetails";

const ORDER_STATUSES = ["Pending", "Confirmed", "Preparing", "Ready for Pickup", "Picked Up", "Completed", "Out for Delivery", "Delivered", "Cancelled"];
const formatMoney = (value, currency = "CAD") => new Intl.NumberFormat("en-CA", { style: "currency", currency: currency || "CAD" }).format(Number(value || 0));
const formatDate = (value) => value ? new Date(value).toLocaleString("en-CA", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }) : "Unknown";

function AdminOrders() {
  const { groups } = useAuth();
  const [orders, setOrders] = useState([]);
  const [selectedOrder, setSelectedOrder] = useState(null);
  const [filters, setFilters] = useState({ search: "", status: "", paymentStatus: "", deliveryMethod: "" });
  const [loading, setLoading] = useState(true);
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let active = true;
    fetchAdminOrders().then((data) => { if (active) setOrders(data); })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const loadOrders = async (event) => {
    event?.preventDefault(); setLoading(true); setError("");
    try { setOrders(await fetchAdminOrders(filters)); }
    catch (requestError) { setError(requestError.message); }
    finally { setLoading(false); }
  };

  const openOrder = async (orderId) => {
    setError("");
    try { setSelectedOrder(await fetchAdminOrder(orderId)); }
    catch (requestError) { setError(requestError.message); }
  };

  const changeStatus = async (orderStatus) => {
    if (!window.confirm(`Change this order to ${orderStatus}?`)) return;
    setUpdating(true); setError(""); setMessage("");
    try {
      const updated = await updateAdminOrderStatus(selectedOrder.orderId, orderStatus);
      setSelectedOrder(updated);
      setOrders((current) => current.map((order) => order.orderId === updated.orderId ? updated : order));
      setMessage(`Order ${updated.orderId} moved to ${updated.orderStatus}.`);
    } catch (requestError) {
      setError(requestError.message);
      try { setSelectedOrder(await fetchAdminOrder(selectedOrder.orderId)); } catch { /* keep existing details */ }
    } finally { setUpdating(false); }
  };

  const updateFilter = ({ target }) => setFilters((current) => ({ ...current, [target.name]: target.value }));

  return (
    <section className="admin-dashboard">
      <div className="admin-page-title"><div><p className="admin-eyebrow">Eatinity Administration</p><h1>Order Management</h1></div><button className="admin-button secondary" onClick={loadOrders}>Refresh</button></div>
      {error && <div className="admin-alert error">{error}</div>}{message && <div className="admin-alert success">{message}</div>}

      <form className="admin-filters admin-order-filters" onSubmit={loadOrders}>
        <input aria-label="Search orders" name="search" placeholder="Order, customer, email or phone" value={filters.search} onChange={updateFilter} />
        <select name="status" value={filters.status} onChange={updateFilter}><option value="">All statuses</option>{ORDER_STATUSES.map((status) => <option key={status}>{status}</option>)}</select>
        <select name="paymentStatus" value={filters.paymentStatus} onChange={updateFilter}><option value="">All payments</option><option>Paid</option><option>Pending Payment</option><option>Refunded</option></select>
        <select name="deliveryMethod" value={filters.deliveryMethod} onChange={updateFilter}><option value="">All methods</option><option>Pickup</option><option>Delivery</option></select>
        <button className="admin-button primary" type="submit">Apply</button>
      </form>

      {selectedOrder && <AdminOrderDetails order={selectedOrder} groups={groups} updating={updating} onClose={() => setSelectedOrder(null)} onStatusChange={changeStatus} />}

      {loading ? <p>Loading orders...</p> : <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>Order</th><th>Customer</th><th>Date</th><th>Method</th><th>Payment</th><th>Status</th><th>Total</th><th></th></tr></thead>
        <tbody>
          {orders.map((order) => <tr key={order.orderId}><td><strong>{order.orderId}</strong></td><td>{order.customerName}<small>{order.customerEmail}</small></td><td>{formatDate(order.createdAt)}</td><td>{order.deliveryMethod}</td><td>{order.paymentStatus}</td><td><span className="admin-status unavailable">{order.orderStatus}</span></td><td>{formatMoney(order.amountPaid || order.totalAmount, order.currency)}</td><td><button className="admin-button secondary" onClick={() => openOrder(order.orderId)}>View</button></td></tr>)}
          {!orders.length && <tr><td colSpan="8">No orders match these filters.</td></tr>}
        </tbody>
      </table></div>}
    </section>
  );
}

export default AdminOrders;

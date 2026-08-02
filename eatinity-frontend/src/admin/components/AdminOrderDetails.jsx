import { getNextOrderStatuses } from "../utils/orderWorkflow";

const formatMoney = (value, currency = "CAD") => new Intl.NumberFormat("en-CA", {
  style: "currency", currency: currency || "CAD",
}).format(Number(value || 0));

const formatDate = (value) => value ? new Date(value).toLocaleString("en-CA", {
  year: "numeric", month: "short", day: "numeric", hour: "numeric", minute: "2-digit",
}) : "Not available";

function AdminOrderDetails({ order, groups, updating, onClose, onStatusChange }) {
  const nextStatuses = getNextOrderStatuses(order, groups);
  const address = order.address || {};

  return (
    <section className="admin-order-details">
      <div className="admin-form-header">
        <div><p className="admin-eyebrow">Order details</p><h2>{order.orderId}</h2></div>
        <button className="admin-button secondary" type="button" onClick={onClose}>Close</button>
      </div>

      <div className="admin-order-summary-grid">
        <div><span>Customer</span><strong>{order.customerName || "Unknown"}</strong><small>{order.customerEmail}</small><small>{order.customerPhone}</small></div>
        <div><span>Order</span><strong>{order.orderStatus || "Pending"}</strong><small>{formatDate(order.createdAt)}</small></div>
        <div><span>Payment</span><strong>{order.paymentStatus || "Unknown"}</strong><small>{formatMoney(order.amountPaid || order.totalAmount, order.currency)}</small></div>
        <div><span>Fulfilment</span><strong>{order.deliveryMethod || "Pickup"}</strong>{address.street && <small>{address.street}, {address.city} {address.postalCode}</small>}</div>
      </div>

      <h3>Items</h3>
      <div className="admin-order-items">
        {(order.items || []).map((item, index) => (
          <div key={item.id || `${order.orderId}-${index}`}><span>{item.name} × {item.quantity || 1}</span><strong>{formatMoney(Number(item.price || 0) * Number(item.quantity || 1), order.currency)}</strong></div>
        ))}
      </div>

      <div className="admin-order-totals">
        <p><span>Subtotal</span><strong>{formatMoney(order.subtotalAmount, order.currency)}</strong></p>
        <p><span>Tax</span><strong>{formatMoney(order.taxAmount, order.currency)}</strong></p>
        <p><span>Total</span><strong>{formatMoney(order.amountPaid || order.totalAmount, order.currency)}</strong></p>
      </div>

      <h3>Next action</h3>
      <div className="admin-status-actions">
        {!!nextStatuses.length && <select aria-label="Change order status" disabled={updating} defaultValue="" onChange={(event) => { if (event.target.value) onStatusChange(event.target.value); event.target.value = ""; }}>
          <option value="" disabled>{updating ? "Updating..." : "Select a new status"}</option>
          {nextStatuses.map((status) => <option key={status} value={status}>{status}</option>)}
        </select>}
        {!nextStatuses.length && <p>No status actions are available for your role.</p>}
      </div>

      {order.readyNotificationSentAt && <div className="admin-alert success">Ready-for-pickup email sent {formatDate(order.readyNotificationSentAt)}.</div>}
      {order.readyNotificationError && <div className="admin-alert error">Ready email failed: {order.readyNotificationError}</div>}

      <h3>Status history</h3>
      <div className="admin-status-history">
        {(order.statusHistory || []).map((entry, index) => <div key={`${entry.changedAt}-${index}`}><strong>{entry.from} → {entry.to}</strong><span>{formatDate(entry.changedAt)}</span><small>Changed by {entry.changedBy}</small></div>)}
        {!order.statusHistory?.length && <p>No status changes have been recorded yet.</p>}
      </div>
    </section>
  );
}

export default AdminOrderDetails;

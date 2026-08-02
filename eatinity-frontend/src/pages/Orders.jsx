import { Link, useNavigate } from "react-router-dom";
import { useEffect, useState } from "react";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { useAuth } from "../auth/AuthContext";
import { fetchUserOrders } from "../api/userProfileApi";

function formatMoney(value, currency = "CAD") {
  const amount = Number(value || 0);
  return new Intl.NumberFormat("en-CA", {
    style: "currency",
    currency: currency || "CAD",
  }).format(amount);
}

function formatDate(value) {
  if (!value) {
    return "Date not available";
  }

  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return value;
  }

  return date.toLocaleString("en-CA", {
    year: "numeric",
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

function Orders() {
  const navigate = useNavigate();
  const { isAuthenticated, authLoading } = useAuth();
  const [orders, setOrders] = useState([]);
  const [loading, setLoading] = useState(true);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      navigate("/signin", { state: { from: "/orders" } });
    }
  }, [authLoading, isAuthenticated, navigate]);

  useEffect(() => {
    const loadOrders = async () => {
      if (authLoading || !isAuthenticated) {
        return;
      }

      try {
        setLoading(true);
        setMessage("");
        const userOrders = await fetchUserOrders();
        setOrders(userOrders);
      } catch (error) {
        console.error("Orders load failed:", error);
        setMessage(error.message || "Unable to load your orders right now.");
      } finally {
        setLoading(false);
      }
    };

    loadOrders();
  }, [authLoading, isAuthenticated]);

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="account-page">
        <div className="account-card">
          <Link className="account-exit" to="/" aria-label="Go to home page" title="Go to home page">
            ×
          </Link>
          <div className="account-header">
            <h1>My Orders</h1>
            <p>Review the orders connected to your signed-in account.</p>
          </div>

          {authLoading || loading ? (
            <div className="account-info-box">Loading your orders...</div>
          ) : message ? (
            <div className="account-error">{message}</div>
          ) : orders.length === 0 ? (
            <div className="account-info-box">
              You do not have any saved orders yet. Your next signed-in checkout will appear here.
            </div>
          ) : (
            <div className="orders-list">
              {orders.map((order) => (
                <div className="order-card" key={order.orderId}>
                  <div className="order-card-header">
                    <div>
                      <h2>Order {order.orderId}</h2>
                      <p>{formatDate(order.createdAt || order.paidAt)}</p>
                    </div>
                    <div className="order-card-total">
                      {formatMoney(order.amountPaid || order.totalAmount, order.currency || "CAD")}
                    </div>
                  </div>

                  <div className="order-status-row">
                    <span>Payment: {order.paymentStatus || "Pending"}</span>
                    <span>Order: {order.orderStatus || "Pending"}</span>
                  </div>

                  {Array.isArray(order.items) && order.items.length > 0 && (
                    <div className="order-items">
                      {order.items.map((item, index) => (
                        <div className="order-item" key={item.id || `${order.orderId}-${index}`}>
                          <span>{item.name} × {item.quantity || 1}</span>
                          <span>{formatMoney(Number(item.price || 0) * Number(item.quantity || 1), order.currency || "CAD")}</span>
                        </div>
                      ))}
                    </div>
                  )}
                </div>
              ))}
            </div>
          )}

          <Link className="checkout-link" to="/account">Back to Account</Link>
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default Orders;

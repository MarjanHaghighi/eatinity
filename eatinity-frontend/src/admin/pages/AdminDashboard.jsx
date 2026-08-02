import { Link } from "react-router-dom";
import { useEffect, useMemo, useState } from "react";
import { useAuth } from "../../auth/AuthContext";
import { ADMIN_PERMISSIONS } from "../utils/permissions";
import { fetchAdminOrders } from "../api/adminOrdersApi";
import { fetchAdminProducts } from "../api/adminMenuApi";
import { fetchSalesReport } from "../api/salesReportsApi";

const adminModules = [
  { title: "Order Management", description: "Review and update customer orders.", path: "/admin/orders", permission: ADMIN_PERMISSIONS.MANAGE_ORDERS },
  { title: "Food Management", description: "Create and maintain menu items and categories.", path: "/admin/menu", permission: ADMIN_PERMISSIONS.MANAGE_MENU },
  { title: "Users & Staff", description: "Manage customers, staff, and permissions.", path: "/admin/users", permission: ADMIN_PERMISSIONS.MANAGE_USERS },
  { title: "Sales Reports", description: "View daily, weekly, and monthly sales.", path: "/admin/reports", permission: ADMIN_PERMISSIONS.VIEW_REPORTS },
  { title: "Audit Log", description: "Review administrative changes and their actors.", path: "/admin/audit-log", permission: ADMIN_PERMISSIONS.VIEW_AUDIT_LOG },
];

const money = (value) => new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(Number(value || 0));
const shortDate = (value) => value ? new Date(value).toLocaleString("en-CA", { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" }) : "Unknown";

function AdminDashboard() {
  const { user, hasPermission } = useAuth();
  const [orders, setOrders] = useState([]);
  const [products, setProducts] = useState([]);
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [warnings, setWarnings] = useState([]);
  const visibleModules = adminModules.filter((module) =>
    hasPermission(module.permission)
  );

  useEffect(() => {
    let active = true;
    Promise.allSettled([
      fetchAdminOrders(),
      fetchAdminProducts(),
      fetchSalesReport({ period: "today" }),
    ]).then((results) => {
      if (!active) return;
      const messages = [];
      if (results[0].status === "fulfilled") setOrders(results[0].value);
      else messages.push(`Orders: ${results[0].reason.message}`);
      if (results[1].status === "fulfilled") setProducts(results[1].value);
      else messages.push(`Menu: ${results[1].reason.message}`);
      if (results[2].status === "fulfilled") setReport(results[2].value);
      else messages.push(`Sales: ${results[2].reason.message}`);
      setWarnings(messages);
      setLoading(false);
    });
    return () => { active = false; };
  }, []);

  const dashboard = useMemo(() => {
    const countStatus = (status) => orders.filter((order) => order.orderStatus === status).length;
    const recentOrders = [...orders].sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt))).slice(0, 5);
    return {
      pending: countStatus("Pending") + countStatus("Confirmed"),
      preparing: countStatus("Preparing"),
      ready: countStatus("Ready for Pickup") + countStatus("Out for Delivery"),
      unavailable: products.filter((product) => !product.archived && product.available === false).length,
      recentOrders,
    };
  }, [orders, products]);

  const summaryCards = [
    ["Today's Sales", money(report?.summary?.grossSales)],
    ["Paid Orders Today", report?.summary?.paidOrderCount ?? 0],
    ["Pending / Confirmed", dashboard.pending],
    ["Preparing", dashboard.preparing],
    ["Ready / Delivery", dashboard.ready],
    ["Unavailable Menu Items", dashboard.unavailable],
  ];

  return (
    <section className="admin-dashboard">
          <div className="admin-dashboard-header">
            <div>
              <p className="admin-eyebrow">Eatinity Administration</p>
              <h1>Admin Dashboard</h1>
              <p>Welcome, {user?.name || user?.email || "Administrator"}.</p>
            </div>
            <Link className="admin-store-link" to="/">View Store</Link>
          </div>

          {warnings.length > 0 && <div className="admin-alert error">Some dashboard sections could not load:<ul>{warnings.map((warning) => <li key={warning}>{warning}</li>)}</ul></div>}

          {loading ? <p>Loading dashboard...</p> : <>
            <div className="admin-dashboard-stats">
              {summaryCards.map(([label, value]) => <article key={label}><span>{label}</span><strong>{value}</strong></article>)}
            </div>

            <div className="admin-dashboard-data-grid">
              <section className="admin-report-panel">
                <div className="admin-panel-heading"><h2>Recent Orders</h2><Link to="/admin/orders">View all</Link></div>
                <div className="admin-dashboard-list">
                  {dashboard.recentOrders.map((order) => <Link key={order.orderId} to="/admin/orders"><span><strong>{order.orderId}</strong><small>{order.customerName} · {shortDate(order.createdAt)}</small></span><span>{money(order.amountPaid || order.totalAmount)}<small>{order.orderStatus}</small></span></Link>)}
                  {!dashboard.recentOrders.length && <p>No recent orders.</p>}
                </div>
              </section>

              <section className="admin-report-panel">
                <div className="admin-panel-heading"><h2>Today's Best Sellers</h2><Link to="/admin/reports">View report</Link></div>
                <div className="admin-dashboard-list">
                  {(report?.products || []).slice(0, 5).map((product) => <div key={product.name}><span><strong>{product.name}</strong><small>{product.quantity} sold</small></span><strong>{money(product.sales)}</strong></div>)}
                  {!report?.products?.length && <p>No product sales today.</p>}
                </div>
              </section>
            </div>
          </>}

          <div className="admin-module-grid">
            {visibleModules.map((module) => (
              <article className="admin-module-card" key={module.title}>
                <h2>{module.title}</h2>
                <p>{module.description}</p>
                <Link to={module.path}>Open {module.title}</Link>
              </article>
            ))}
          </div>
    </section>
  );
}

export default AdminDashboard;

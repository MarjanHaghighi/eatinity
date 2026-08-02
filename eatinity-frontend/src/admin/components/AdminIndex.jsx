import { Navigate } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import { ADMIN_PERMISSIONS } from "../utils/permissions";
import AdminDashboard from "../pages/AdminDashboard";

function AdminIndex() {
  const { hasPermission } = useAuth();

  if (!hasPermission(ADMIN_PERMISSIONS.VIEW_DASHBOARD)) {
    return <Navigate to="/admin/orders" replace />;
  }

  return <AdminDashboard />;
}

export default AdminIndex;

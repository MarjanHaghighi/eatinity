import { Navigate, Outlet, useLocation } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";

function AdminRoute({ permission }) {
  const location = useLocation();
  const { authLoading, isAuthenticated, isAdmin, hasPermission } = useAuth();

  if (authLoading) {
    return <div className="admin-route-message">Checking admin access...</div>;
  }

  if (!isAuthenticated) {
    return <Navigate to="/signin" state={{ from: location.pathname }} replace />;
  }

  if (!isAdmin) {
    return <Navigate to="/account" replace />;
  }

  if (permission && !hasPermission(permission)) {
    return <Navigate to="/admin" replace />;
  }

  return <Outlet />;
}

export default AdminRoute;

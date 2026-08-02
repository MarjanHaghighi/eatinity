import { NavLink } from "react-router-dom";
import { useAuth } from "../../auth/AuthContext";
import {
  ADMIN_NAV_ITEMS,
  getPrimaryAdminRole,
} from "../utils/permissions";

function AdminSidebar() {
  const { groups, hasPermission } = useAuth();
  const role = getPrimaryAdminRole(groups);
  const visibleItems = ADMIN_NAV_ITEMS.filter((item) =>
    hasPermission(item.permission)
  );

  return (
    <aside className="admin-sidebar" aria-label="Admin navigation">
      <div className="admin-sidebar-heading">
        <strong>Administration</strong>
        <span>{role?.replace("-", " ") || "staff"}</span>
      </div>

      <nav>
        {visibleItems.map((item) => (
          <NavLink
            className={({ isActive }) =>
              `admin-sidebar-link${isActive ? " active" : ""}`
            }
            end={item.path === "/admin"}
            key={item.path}
            to={item.path}
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}

export default AdminSidebar;

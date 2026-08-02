import { Outlet } from "react-router-dom";
import Navbar from "../../components/navbar";
import Footer from "../../components/Footer";
import AdminSidebar from "./AdminSidebar";
import "../styles/admin.css";

function AdminLayout() {
  return (
    <div className="app">
      <Navbar cart={[]} />
      <div className="admin-shell">
        <AdminSidebar />
        <main className="admin-content">
          <Outlet />
        </main>
      </div>
      <Footer />
    </div>
  );
}

export default AdminLayout;

import { BrowserRouter, Routes, Route } from "react-router-dom";
import { useState } from "react";
import Home from "./pages/home";
import Cart from "./pages/cart";
import Checkout from "./pages/Checkout";
import SignUp from "./pages/SignUp";
import ConfirmSignUp from "./pages/ConfirmSignUp";
import SignIn from "./pages/SignIn";
import Account from "./pages/Account";
import Orders from "./pages/Orders";
import Addresses from "./pages/Addresses";
import PaymentMethods from "./pages/PaymentMethods";
import "./App.css";
import Success from "./pages/success";
import Cancel from "./pages/cancel";
import { AuthProvider } from "./auth/AuthContext";
import AdminRoute from "./admin/components/AdminRoute";
import AdminLayout from "./admin/components/AdminLayout";
import AdminIndex from "./admin/components/AdminIndex";
import { ADMIN_PERMISSIONS } from "./admin/utils/permissions";
import AdminMenu from "./admin/pages/AdminMenu";
import AdminOrders from "./admin/pages/AdminOrders";
import AdminUsers from "./admin/pages/AdminUsers";
import AdminReports from "./admin/pages/AdminReports";
import AdminAuditLog from "./admin/pages/AdminAuditLog";

function App() {
  const [cart, setCart] = useState([]);

  const addToCart = (product) => {
    if (product.available === false || product.archived === true) {
      return;
    }

    setCart((prevCart) => {
      const existingItem = prevCart.find((item) => item.id === product.id);

      if (existingItem) {
        return prevCart.map((item) =>
          item.id === product.id
            ? { ...item, quantity: item.quantity + 1 }
            : item
        );
      }

      return [...prevCart, { ...product, quantity: 1 }];
    });
  };

  const increaseItem = (id) => {
    setCart((prevCart) =>
      prevCart.map((item) =>
        item.id === id ? { ...item, quantity: item.quantity + 1 } : item
      )
    );
  };

  const decreaseItem = (id) => {
    setCart((prevCart) =>
      prevCart
        .map((item) =>
          item.id === id ? { ...item, quantity: item.quantity - 1 } : item
        )
        .filter((item) => item.quantity > 0)
    );
  };

  const deleteItem = (id) => {
    setCart((prevCart) => prevCart.filter((item) => item.id !== id));
  };

  return (
    <BrowserRouter>
      <AuthProvider>
        <Routes>
          <Route path="/" element={<Home cart={cart} addToCart={addToCart} />} />

          <Route
            path="/cart"
            element={
              <Cart
                cart={cart}
                increaseItem={increaseItem}
                decreaseItem={decreaseItem}
                deleteItem={deleteItem}
              />
            }
          />

          <Route path="/checkout" element={<Checkout cart={cart} />} />
          <Route path="/signup" element={<SignUp />} />
          <Route path="/confirm-signup" element={<ConfirmSignUp />} />
          <Route path="/signin" element={<SignIn />} />
          <Route path="/account" element={<Account />} />
          <Route path="/orders" element={<Orders />} />
          <Route path="/addresses" element={<Addresses />} />
          <Route path="/payment-methods" element={<PaymentMethods />} />
          <Route path="/success" element={<Success />} />
          <Route path="/cancel" element={<Cancel />} />
          <Route element={<AdminRoute />}>
            <Route path="/admin" element={<AdminLayout />}>
              <Route index element={<AdminIndex />} />
              <Route element={<AdminRoute permission={ADMIN_PERMISSIONS.MANAGE_ORDERS} />}>
                <Route path="orders" element={<AdminOrders />} />
              </Route>
              <Route element={<AdminRoute permission={ADMIN_PERMISSIONS.MANAGE_MENU} />}>
                <Route path="menu" element={<AdminMenu />} />
              </Route>
              <Route element={<AdminRoute permission={ADMIN_PERMISSIONS.MANAGE_USERS} />}>
                <Route path="users" element={<AdminUsers />} />
              </Route>
              <Route element={<AdminRoute permission={ADMIN_PERMISSIONS.VIEW_REPORTS} />}>
                <Route path="reports" element={<AdminReports />} />
              </Route>
              <Route element={<AdminRoute permission={ADMIN_PERMISSIONS.VIEW_AUDIT_LOG} />}>
                <Route path="audit-log" element={<AdminAuditLog />} />
              </Route>
            </Route>
          </Route>
        </Routes>
      </AuthProvider>
    </BrowserRouter>
  );
}

export default App;


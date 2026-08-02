import { Link, useNavigate } from "react-router-dom";
import logo from "../assets/Logo-Eatinity.png";
import { useEffect, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { API_BASE_URL } from "../config";

const FALLBACK_CATEGORIES = [
  { categoryId: "main-food", name: "Main Food" },
  { categoryId: "burger", name: "Burger" },
  { categoryId: "sandwich", name: "Sandwich" },
  { categoryId: "pizza", name: "Pizza" },
  { categoryId: "salad", name: "Salad" },
  { categoryId: "soup", name: "Soup" },
  { categoryId: "dessert", name: "Dessert" },
  { categoryId: "drink", name: "Drinks" },
];

function Navbar({ cart = [] }) {
  const navigate = useNavigate();
  const { isAuthenticated, isAdmin, logout } = useAuth();
  const [menuCategories, setMenuCategories] = useState(FALLBACK_CATEGORIES);
  const totalItems = cart.reduce((sum, item) => sum + item.quantity, 0);

  useEffect(() => {
    fetch(`${API_BASE_URL}/categories`)
      .then((response) => {
        if (!response.ok) throw new Error("Categories could not be loaded.");
        return response.json();
      })
      .then((data) => setMenuCategories(data.categories || FALLBACK_CATEGORIES))
      .catch(() => setMenuCategories(FALLBACK_CATEGORIES));
  }, []);

  const handleSignOut = () => {
    logout();
    navigate("/");
  };

  return (
    <nav className="navbar">
      <Link to="/">
        <img
          src={logo}
          alt="Eatinity"
          className="logo-image"
        />
      </Link>

      <ul className="nav-links">
        <li><Link to="/">Home</Link></li>

        <li className="dropdown">
          <a href="#menu">Menu ▾</a>

          <ul className="dropdown-menu">
            {menuCategories.map((category) => (
              <li key={category.categoryId}>
                <a href={`/#${category.categoryId}`}>{category.name}</a>
              </li>
            ))}
          </ul>
        </li>

        <li><a href="#about">About Us</a></li>
        <li><a href="#contact">Contact</a></li>

        {isAdmin && <li><Link to="/admin">Admin</Link></li>}

        {!isAuthenticated ? (
          <li><Link to="/signin">Account</Link></li>
        ) : (
          <li className="dropdown account-dropdown">
            <Link to="/account">Account ▾</Link>
            <ul className="dropdown-menu account-menu">
              <li><Link to="/account">Profile</Link></li>
              <li><Link to="/orders">My Orders</Link></li>
              <li><Link to="/addresses">Addresses</Link></li>
<li>
                <button className="account-signout" type="button" onClick={handleSignOut}>
                  Sign Out
                </button>
              </li>
            </ul>
          </li>
        )}

        <li>
          <Link to="/cart" className="cart-link">
            <span>Cart</span>
            <span className="cart-emoji">🛒</span>
            {totalItems > 0 && <span className="cart-count">{totalItems}</span>}
          </Link>
        </li>
      </ul>
    </nav>
  );
}

export default Navbar;



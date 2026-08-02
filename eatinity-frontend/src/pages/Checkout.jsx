import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { useAuth } from "../auth/AuthContext";
import { fetchUserProfile, updateUserProfile } from "../api/userProfileApi";
import { getIdToken } from "../auth/authService";
import { API_BASE_URL } from "../config";

const GUEST_CHECKOUT_API_URL = `${API_BASE_URL}/create-checkout-session`;
const AUTHENTICATED_CHECKOUT_API_URL = `${API_BASE_URL}/authenticated/create-checkout-session`;

function Checkout({ cart = [] }) {
  const { isAuthenticated } = useAuth();
  const [customerName, setCustomerName] = useState("");
  const [customerEmail, setCustomerEmail] = useState("");
  const [customerPhone, setCustomerPhone] = useState("");
  const [profileMessage, setProfileMessage] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const loadProfile = async () => {
      if (!isAuthenticated) {
        return;
      }

      try {
        const profile = await fetchUserProfile();

        if (!profile) {
          return;
        }

        setCustomerName(profile.name || "");
        setCustomerEmail(profile.email || "");
        setCustomerPhone(profile.phone || "");
        setProfileMessage("Your saved account information was loaded.");
      } catch (error) {
        console.error("Profile load failed:", error);
        setProfileMessage("Signed in, but saved profile could not be loaded.");
      }
    };

    loadProfile();
  }, [isAuthenticated]);

  const subtotal = cart.reduce((sum, item) => {
    return sum + Number(item.price || 0) * Number(item.quantity || 1);
  }, 0);

  const tax = subtotal * 0.13;
  const total = subtotal + tax;

  const handleCheckout = async () => {
    if (cart.length === 0) {
      alert("Cart is empty.");
      return;
    }

    if (!customerName || !customerEmail || !customerPhone) {
      alert("Please enter name, email, and phone.");
      return;
    }

    try {
      setLoading(true);

      if (isAuthenticated) {
        try {
          await updateUserProfile({
            name: customerName,
            phone: customerPhone,
            defaultDeliveryMethod: "Pickup",
          });
        } catch (profileError) {
          console.warn("Profile update skipped:", profileError);
        }
      }

      const token = isAuthenticated ? await getIdToken() : null;
      const response = await fetch(
        token ? AUTHENTICATED_CHECKOUT_API_URL : GUEST_CHECKOUT_API_URL,
        {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(token ? { Authorization: `Bearer ${token}` } : {}),
          },
          body: JSON.stringify({
            items: cart.map((item) => ({
              id: item.id,
              quantity: Number(item.quantity || 1),
            })),
            customer: {
              name: customerName,
              email: customerEmail,
              phone: customerPhone,
              deliveryMethod: "Pickup",
            },
          }),
        }
      );

      const data = await response.json();

      if (data.url) {
        window.location.href = data.url;
      } else {
        alert(data.error || "Stripe URL not returned.");
      }
    } catch (error) {
      alert("Checkout error: " + error.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={cart} />

      <section className="checkout-page">
        <div className="checkout-card">
          <div className="checkout-header">
            <h1>Checkout</h1>
            <p>Complete your order for pickup.</p>
          </div>

          {cart.length === 0 ? (
            <div className="checkout-empty">
              <p>Your cart is empty.</p>
              <Link to="/" className="checkout-link">
                Back to Menu
              </Link>
            </div>
          ) : (
            <div className="checkout-content">
              <div className="checkout-form-section">
                <h2>Customer Information</h2>

                {!isAuthenticated && (
                  <p className="checkout-profile-hint">
                    Have an account? <Link to="/signin" state={{ from: "/checkout" }}>Sign in</Link> to auto-fill your information.
                  </p>
                )}

                {profileMessage && (
                  <p className="checkout-profile-message">{profileMessage}</p>
                )}

                <input
                  className="checkout-input"
                  type="text"
                  placeholder="Full Name"
                  value={customerName}
                  onChange={(e) => setCustomerName(e.target.value)}
                />

                <input
                  className="checkout-input"
                  type="email"
                  placeholder="Email"
                  value={customerEmail}
                  onChange={(e) => setCustomerEmail(e.target.value)}
                />

                <input
                  className="checkout-input"
                  type="tel"
                  placeholder="Phone"
                  value={customerPhone}
                  onChange={(e) => setCustomerPhone(e.target.value)}
                />
              </div>

              <div className="checkout-summary-section">
                <h2>Order Summary</h2>

                <div className="checkout-items">
                  {cart.map((item, index) => (
                    <div key={item.id || index} className="checkout-item">
                      <span>
                        {item.name} × {item.quantity || 1}
                      </span>
                      <span>
                        ${(Number(item.price || 0) * Number(item.quantity || 1)).toFixed(2)}
                      </span>
                    </div>
                  ))}
                </div>

                <div className="checkout-totals">
                  <p>
                    Subtotal: <span>${subtotal.toFixed(2)}</span>
                  </p>
                  <p>
                    Tax: <span>${tax.toFixed(2)}</span>
                  </p>
                  <h3>
                    Total: <span>${total.toFixed(2)}</span>
                  </h3>
                </div>

                <button
                  className="checkout-button"
                  onClick={handleCheckout}
                  disabled={loading}
                >
                  {loading ? "Processing..." : "Pay with Stripe"}
                </button>
              </div>
            </div>
          )}
        </div>
      </section>

      <Footer />
    </div>
  );
}

export default Checkout;





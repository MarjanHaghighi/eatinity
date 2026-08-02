import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { useAuth } from "../auth/AuthContext";
import { fetchUserProfile, updateUserProfile } from "../api/userProfileApi";

function Account() {
  const navigate = useNavigate();
  const { isAuthenticated, authLoading } = useAuth();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [phone, setPhone] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      navigate("/signin", { state: { from: "/account" } });
    }
  }, [authLoading, isAuthenticated, navigate]);

  useEffect(() => {
    const loadProfile = async () => {
      if (!isAuthenticated) return;

      try {
        setLoading(true);
        const profile = await fetchUserProfile();
        setName(profile?.name || "");
        setEmail(profile?.email || "");
        setPhone(profile?.phone || "");
      } catch (err) {
        setError(err.message || "Could not load account information.");
      } finally {
        setLoading(false);
      }
    };

    loadProfile();
  }, [isAuthenticated]);

  const handleSave = async (event) => {
    event.preventDefault();
    setMessage("");
    setError("");

    try {
      setSaving(true);
      const profile = await updateUserProfile({
        name,
        phone,
        defaultDeliveryMethod: "Pickup",
});
      setName(profile?.name || name);
      setPhone(profile?.phone || phone);
      setMessage("Account information saved.");
    } catch (err) {
      setError(err.message || "Could not save account information.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="account-page">
        <div className="account-card">
          <Link className="account-exit" to="/" aria-label="Go to home page" title="Go to home page">
            ×
          </Link>
          <div className="account-header">
            <h1>Account</h1>
            <p>Manage your basic Eatinity profile information.</p>
          </div>

          <div className="account-nav-cards">
            <Link to="/orders">My Orders</Link>
            <Link to="/addresses">Addresses</Link>
</div>

          {loading ? (
            <p>Loading account...</p>
          ) : (
            <form className="account-form" onSubmit={handleSave}>
              {message && <div className="auth-success">{message}</div>}
              {error && <div className="auth-error">{error}</div>}

              <label>
                Full Name
                <input
                  className="auth-input"
                  type="text"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                />
              </label>

              <label>
                Email
                <input
                  className="auth-input"
                  type="email"
                  value={email}
                  disabled
                />
              </label>

              <label>
                Phone
                <input
                  className="auth-input"
                  type="tel"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </label>

              <button className="auth-button" type="submit" disabled={saving}>
                {saving ? "Saving..." : "Save Account"}
              </button>
            </form>
          )}
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default Account;



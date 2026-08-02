import { useEffect, useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { useAuth } from "../auth/AuthContext";
import { fetchUserProfile, updateUserProfile } from "../api/userProfileApi";

function Addresses() {
  const navigate = useNavigate();
  const { isAuthenticated, authLoading } = useAuth();
  const [street, setStreet] = useState("");
  const [city, setCity] = useState("");
  const [province, setProvince] = useState("ON");
  const [postalCode, setPostalCode] = useState("");
  const [name, setName] = useState("");
  const [phone, setPhone] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      navigate("/signin", { state: { from: "/addresses" } });
    }
  }, [authLoading, isAuthenticated, navigate]);

  useEffect(() => {
    const loadProfile = async () => {
      if (!isAuthenticated) return;

      try {
        setLoading(true);
        const profile = await fetchUserProfile();
        setName(profile?.name || "");
        setPhone(profile?.phone || "");
        setStreet(profile?.address?.street || "");
        setCity(profile?.address?.city || "");
        setProvince(profile?.address?.province || "ON");
        setPostalCode(profile?.address?.postalCode || "");
      } catch (err) {
        setError(err.message || "Could not load address.");
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
      await updateUserProfile({
        name,
        phone,
        defaultDeliveryMethod: "Pickup",
        address: {
          street,
          city,
          province,
          postalCode,
        },
      });
      setMessage("Address saved.");
    } catch (err) {
      setError(err.message || "Could not save address.");
    } finally {
      setSaving(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="account-page">
        <div className="account-card">
          <div className="account-header">
            <h1>Addresses</h1>
            <p>Save your address for future delivery options.</p>
          </div>

          {loading ? (
            <p>Loading address...</p>
          ) : (
            <form className="account-form" onSubmit={handleSave}>
              {message && <div className="auth-success">{message}</div>}
              {error && <div className="auth-error">{error}</div>}

              <label>
                Street Address
                <input className="auth-input" value={street} onChange={(e) => setStreet(e.target.value)} />
              </label>
              <label>
                City
                <input className="auth-input" value={city} onChange={(e) => setCity(e.target.value)} />
              </label>
              <label>
                Province
                <input className="auth-input" value={province} onChange={(e) => setProvince(e.target.value)} />
              </label>
              <label>
                Postal Code
                <input className="auth-input" value={postalCode} onChange={(e) => setPostalCode(e.target.value)} />
              </label>

              <button className="auth-button" type="submit" disabled={saving}>
                {saving ? "Saving..." : "Save Address"}
              </button>
            </form>
          )}

          <Link className="checkout-link" to="/account">Back to Account</Link>
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default Addresses;

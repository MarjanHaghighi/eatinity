import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { confirmSignUp } from "../auth/authService";

function ConfirmSignUp() {
  const navigate = useNavigate();
  const location = useLocation();
  const [email, setEmail] = useState(location.state?.email || "");
  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError("");
    setSuccess("");

    if (!email || !code) {
      setError("Please enter email and verification code.");
      return;
    }

    try {
      setLoading(true);
      await confirmSignUp({ email, code });
      setSuccess("Account confirmed successfully. Redirecting to sign in...");
      setTimeout(() => navigate("/signin", { state: { email } }), 900);
    } catch (err) {
      setError(err.message || "Confirmation failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="auth-page">
        <div className="auth-card">
          <h1>Confirm Account</h1>
          <p className="auth-subtitle">Enter the verification code sent to your email.</p>

          {error && <div className="auth-error">{error}</div>}
          {success && <div className="auth-success">{success}</div>}

          <form onSubmit={handleSubmit} className="auth-form">
            <input
              className="auth-input"
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <input
              className="auth-input"
              type="text"
              placeholder="Verification Code"
              value={code}
              onChange={(e) => setCode(e.target.value)}
            />
            <button className="auth-button" type="submit" disabled={loading}>
              {loading ? "Confirming..." : "Confirm Account"}
            </button>
          </form>

          <p className="auth-footer-text">
            Already confirmed? <Link to="/signin">Sign in</Link>
          </p>
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default ConfirmSignUp;

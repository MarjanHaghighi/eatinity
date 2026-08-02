import { useState } from "react";
import { Link, useNavigate } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { signUp } from "../auth/authService";

function SignUp() {
  const navigate = useNavigate();
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError("");

    if (!name || !email || !password) {
      setError("Please enter name, email, and password.");
      return;
    }

    try {
      setLoading(true);
      await signUp({ name, email, password });
      navigate("/confirm-signup", { state: { email } });
    } catch (err) {
      setError(err.message || "Sign up failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="auth-page">
        <div className="auth-card">
          <h1>Create Account</h1>
          <p className="auth-subtitle">Create your Eatinity account for faster checkout.</p>

          {error && <div className="auth-error">{error}</div>}

          <form onSubmit={handleSubmit} className="auth-form">
            <input
              className="auth-input"
              type="text"
              placeholder="Full Name"
              value={name}
              onChange={(e) => setName(e.target.value)}
            />
            <input
              className="auth-input"
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
            />
            <input
              className="auth-input"
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
            />
            <button className="auth-button" type="submit" disabled={loading}>
              {loading ? "Creating..." : "Create Account"}
            </button>
          </form>

          <p className="auth-footer-text">
            Already have an account? <Link to="/signin">Sign in</Link>
          </p>
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default SignUp;

import { useState } from "react";
import { Link, useLocation, useNavigate } from "react-router-dom";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { completeNewPassword, signIn } from "../auth/authService";
import { useAuth } from "../auth/AuthContext";

function SignIn() {
  const navigate = useNavigate();
  const location = useLocation();
  const { refreshAuth } = useAuth();
  const [email, setEmail] = useState(location.state?.email || "");
  const [password, setPassword] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmNewPassword, setConfirmNewPassword] = useState("");
  const [passwordChallenge, setPasswordChallenge] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");

  const handleSubmit = async (event) => {
    event.preventDefault();
    setError("");

    if (!passwordChallenge && (!email || !password)) {
      setError("Please enter email and password.");
      return;
    }

    if (passwordChallenge && (!newPassword || !confirmNewPassword)) {
      setError("Please enter and confirm your new password.");
      return;
    }
    if (passwordChallenge && newPassword !== confirmNewPassword) {
      setError("The new passwords do not match.");
      return;
    }

    try {
      setLoading(true);
      if (passwordChallenge) {
        await completeNewPassword({
          user: passwordChallenge.user,
          newPassword,
          userAttributes: passwordChallenge.userAttributes,
        });
      } else {
        const result = await signIn({ email, password });
        if (result.challenge === "NEW_PASSWORD_REQUIRED") {
          setPasswordChallenge(result);
          setPassword("");
          return;
        }
      }
      await refreshAuth();
      navigate(location.state?.from || "/");
    } catch (err) {
      setError(err.message || "Sign in failed.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="auth-page">
        <div className="auth-card">
          <h1>{passwordChallenge ? "Choose New Password" : "Sign In"}</h1>
          <p className="auth-subtitle">
            {passwordChallenge
              ? "Create a permanent password for your recovered account."
              : "Sign in to use your saved checkout information."}
          </p>

          {error && <div className="auth-error">{error}</div>}

          <form onSubmit={handleSubmit} className="auth-form">
            {!passwordChallenge ? (
              <>
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
              </>
            ) : (
              <>
                <input
                  className="auth-input"
                  type="password"
                  placeholder="New password"
                  value={newPassword}
                  onChange={(e) => setNewPassword(e.target.value)}
                />
                <input
                  className="auth-input"
                  type="password"
                  placeholder="Confirm new password"
                  value={confirmNewPassword}
                  onChange={(e) => setConfirmNewPassword(e.target.value)}
                />
              </>
            )}
            <button className="auth-button" type="submit" disabled={loading}>
              {loading
                ? (passwordChallenge ? "Saving password..." : "Signing in...")
                : (passwordChallenge ? "Set Password and Sign In" : "Sign In")}
            </button>
          </form>

          {!passwordChallenge && (
            <p className="auth-footer-text">
              New to Eatinity? <Link to="/signup">Create account</Link>
            </p>
          )}
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default SignIn;


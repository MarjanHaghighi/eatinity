import { Link, useSearchParams } from "react-router-dom";
import logo from "../assets/Logo-Eatinity.png";
import "../App.css";

function Success() {
  const [searchParams] = useSearchParams();
  const sessionId = searchParams.get("session_id");

  const today = new Date().toLocaleDateString("en-CA", {
    year: "numeric",
    month: "long",
    day: "numeric",
  });

  const shortOrderId = sessionId
    ? `#EN-${sessionId.slice(-8).toUpperCase()}`
    : "#EN-PENDING";

  return (
    <div className="success-page">
      <header className="success-header">
        <div className="success-logo-box">
          <img src={logo} alt="Eatinity Logo" className="success-logo" />
          <div>
            <h2>Eatinity</h2>
            <p>Fresh Healthy Infinitive Taste.</p>
          </div>
        </div>

        <Link to="/" className="back-home">⌂ Back to Home</Link>
      </header>

      <main className="success-main">
        <section className="success-card">
          <div className="success-icon">✓</div>

          <h1>Thank You!</h1>
          <p className="success-subtitle">
            Your order has been placed successfully.
          </p>

          <div className="success-badge">✓ Payment Successful</div>

          <div className="success-divider"></div>

          <p className="success-message">
            We’ve received your payment and will start preparing your delicious
            meals right away. 🧡
          </p>

          <div className="success-details">
            <div>
              <span>Order Number</span>
              <strong>{shortOrderId}</strong>
            </div>

            <div>
              <span>Date</span>
              <strong>{today}</strong>
            </div>

            <div>
              <span>Payment Result</span>
              <strong>Paid by Card</strong>
            </div>
          </div>

          <div className="success-email">
            ✉ A confirmation email/payment notification will be sent shortly.
          </div>

          <Link to="/" className="continue-btn">
            🛍 Continue Shopping
          </Link>
        </section>

        <p className="success-footer-text">
          🌿 Thank you for choosing Eatinity. <br />
          We appreciate your support!
        </p>
      </main>
    </div>
  );
}

export default Success;
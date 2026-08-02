import { Link } from "react-router-dom";
import logo from "../assets/Logo-Eatinity.png";
import "../App.css";

function Cancel() {
  return (
    <div className="cancel-page">
      <header className="cancel-header">
        <div className="cancel-logo-box">
          <img src={logo} alt="Eatinity Logo" className="cancel-logo" />
          <div>
            <h2>Eatinity</h2>
            <p>Fresh. Healthy. Delivered.</p>
          </div>
        </div>

        <Link to="/" className="cancel-back-home">
          ⌂ Back to Home
        </Link>
      </header>

      <main className="cancel-main">
        <section className="cancel-card">
          <div className="cancel-icon">!</div>

          <h1>Payment Not Completed</h1>

          <p className="cancel-subtitle">
            Your order was not placed because the payment was cancelled or failed.
          </p>

          <div className="cancel-badge">Payment Cancelled</div>

          <div className="cancel-divider"></div>

          <p className="cancel-message">
            No charge was made to your card. You can return to checkout and try
            again whenever you are ready. 🧡
          </p>

          <div className="cancel-warning-box">
            <span className="cancel-cart-icon">🛒</span>
            <p>
              Your cart is still available. <br />
              Please check your payment details and try again.
            </p>
          </div>

          <div className="cancel-buttons">
            <Link to="/checkout" className="retry-btn">
              ↻ Try Payment Again
            </Link>

            <Link to="/" className="cancel-shopping-btn">
              🛍 Continue Shopping
            </Link>
          </div>
        </section>
      </main>
    </div>
  );
}

export default Cancel;
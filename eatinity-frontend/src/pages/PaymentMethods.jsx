import { Link, useNavigate } from "react-router-dom";
import { useEffect } from "react";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import { useAuth } from "../auth/AuthContext";

function PaymentMethods() {
  const navigate = useNavigate();
  const { isAuthenticated, authLoading } = useAuth();

  useEffect(() => {
    if (!authLoading && !isAuthenticated) {
      navigate("/signin", { state: { from: "/payment-methods" } });
    }
  }, [authLoading, isAuthenticated, navigate]);

  return (
    <div className="app">
      <Navbar cart={[]} />
      <section className="account-page">
        <div className="account-card">
          <div className="account-header">
            <h1>Payment Methods</h1>
            <p>Payment methods will be managed securely through Stripe.</p>
          </div>
          <div className="account-info-box">
            We should not store card numbers in DynamoDB. Later, we can add Stripe Customer Portal so customers can safely manage cards.
          </div>
          <Link className="checkout-link" to="/account">Back to Account</Link>
        </div>
      </section>
      <Footer />
    </div>
  );
}

export default PaymentMethods;

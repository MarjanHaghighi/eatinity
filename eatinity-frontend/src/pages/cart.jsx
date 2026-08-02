import { Link } from "react-router-dom";
import Navbar from "../components/navbar";
import CartItem from "../components/CartItem";
import Footer from "../components/Footer";

const TAX_RATE = 0.13;

function Cart({ cart, increaseItem, decreaseItem, deleteItem }) {
  const subtotal = cart.reduce(
    (sum, item) => sum + Number(item.price) * item.quantity,
    0
  );

  const tax = subtotal * TAX_RATE;
  const total = subtotal + tax;

  return (
    <div className="app">
      <Navbar cart={cart} />

      <section className="cart-page">
        <h1>Your Cart</h1>

        {cart.length === 0 ? (
          <div className="empty-cart">
            <p>Your cart is empty.</p>
            <Link to="/" className="continue-btn">Continue Shopping</Link>
          </div>
        ) : (
          <>
            <div className="cart-list">
              {cart.map((item) => (
                <CartItem
                  key={item.id}
                  item={item}
                  increaseItem={increaseItem}
                  decreaseItem={decreaseItem}
                  deleteItem={deleteItem}
                />
              ))}
            </div>

            <div className="cart-summary-box">
              <p>Subtotal: <span>${subtotal.toFixed(2)}</span></p>
              <p>Tax 13%: <span>${tax.toFixed(2)}</span></p>
              <h3>Total: <span>${total.toFixed(2)}</span></h3>

              <div className="cart-buttons">
                <Link to="/" className="continue-btn">
                  Continue Shopping
                </Link>

                <Link to="/checkout" className="checkout-btn">
                  Proceed to Checkout
                </Link>
              </div>
            </div>
          </>
        )}
      </section>

      <Footer />
    </div>
  );
}

export default Cart;
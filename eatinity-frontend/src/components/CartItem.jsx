import { IMAGE_BASE_URL } from "../config";

function CartItem({ item, increaseItem, decreaseItem, deleteItem }) {
  return (
    <div className="cart-page-row">
      <img
        className="cart-small-img"
        src={`${IMAGE_BASE_URL}${item.imagePath}`}
        alt={item.name}
      />

      <div className="cart-product-name">
        <h4>{item.name}</h4>
        <p>${Number(item.price).toFixed(2)} each</p>
      </div>

      <div className="quantity-controls">
        <button type="button" onClick={() => decreaseItem(item.id)}>
          -
        </button>

        <span>{item.quantity}</span>

        <button type="button" onClick={() => increaseItem(item.id)}>
          +
        </button>
      </div>

      <strong className="cart-item-total">
        ${(Number(item.price) * item.quantity).toFixed(2)}
      </strong>

      <button
        type="button"
        className="remove-btn"
        onClick={() => deleteItem(item.id)}
      >
        ✕
      </button>
    </div>
  );
}

export default CartItem;
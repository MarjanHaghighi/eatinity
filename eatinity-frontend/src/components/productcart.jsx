import { IMAGE_BASE_URL } from "../config";

/*const IMAGE_BASE_URL =
  "https://eatinity-s3-images.s3.us-east-1.amazonaws.com/";*/

function ProductCard({ product, addToCart }) {
  const isAvailable = product.available !== false && product.archived !== true;

  return (
    <div className={`product-card${isAvailable ? "" : " product-card-unavailable"}`}>
      <img src={`${IMAGE_BASE_URL}${product.imagePath}`} alt={product.name} />

      <div className="product-info">
        <h4>{product.name}</h4>
        {!isAvailable && <span className="product-unavailable-label">Currently unavailable</span>}
        <p>{product.description}</p>

        <div className="product-footer">
          <span>${Number(product.price).toFixed(2)}</span>
          <button
            disabled={!isAvailable}
            onClick={() => addToCart(product)}
          >
            {isAvailable ? "Add to Cart" : "Unavailable"}
          </button>
        </div>
      </div>
    </div>
  );
}

export default ProductCard;

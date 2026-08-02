import ProductCard from "./productcart";

function CategorySection({ category, products, addToCart }) {
  return (
    <div
      className="category-section"
      id={category.toLowerCase().replaceAll(" ", "-")}
    >
      <div className="category-header">
        <h3>{category}</h3>
        <a className="go-to-menu-top" href="#menu" aria-label={`Go to the top of the menu from ${category}`}>
          ↑ Go to top
        </a>
      </div>

      <div className="products-grid">
        {products.map((product) => (
          <ProductCard
            key={product.id}
            product={product}
            addToCart={addToCart}
          />
        ))}
      </div>
    </div>
  );
}

export default CategorySection;

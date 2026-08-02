import { useEffect, useState } from "react";
import Navbar from "../components/navbar";
import Footer from "../components/Footer";
import CategorySection from "../components/CategorySection";
import { API_BASE_URL, API_URL } from "../config";

/*const API_URL =
  "https://9b057hk84m.execute-api.us-east-1.amazonaws.com/products";*/

function Home({ cart, addToCart }) {
  const [products, setProducts] = useState([]);
  const [categories, setCategories] = useState([]);

  useEffect(() => {
    Promise.all([
      fetch(API_URL).then((res) => res.json()),
      fetch(`${API_BASE_URL}/categories`).then((res) => res.json()),
    ])
      .then(([productData, categoryData]) => {
        setProducts(productData);
        setCategories(categoryData.categories || []);
      })
      .catch((err) => console.error("Error fetching products:", err));
  }, []);

  const groupedProducts = products.reduce((groups, product) => {
    const category = product.category || "other";

    if (!groups[category]) {
      groups[category] = [];
    }

    groups[category].push(product);
    return groups;
  }, {});

  const orderedCategoryIds = [
    ...categories.map((category) => category.categoryId),
    ...Object.keys(groupedProducts).filter(
      (categoryId) => !categories.some((category) => category.categoryId === categoryId)
    ),
  ];

  return (
    <div className="app" id="home">
      <Navbar cart={cart} />

      <section className="hero">
        <h1>Fresh, Healthy & Delicious Food</h1>
        <p>Order your favorite meals from Eatinity and enjoy fast delivery.</p>
        <a href="#menu" className="hero-btn">View Menu</a>
      </section>

      <section className="menu-section" id="menu">
        <h2>Our Menu</h2>
        <p className="section-subtitle">
          Choose from our fresh and tasty food categories.
        </p>

        {orderedCategoryIds.filter((category) => groupedProducts[category]?.length).map((category) => (
            <CategorySection
                key={category}
                category={category}
                products={groupedProducts[category]}
                addToCart={addToCart}
            />
            ))}
      </section>

      <section className="about-section" id="about">
        <h2>About Eatinity</h2>
        <p>
          We provide fresh, healthy meals prepared daily and delivered quickly to
          customers.
        </p>
      </section>

      <section className="contact-section" id="contact">
        <h2>Contact Us</h2>
        <p>Email: support@eatinity.com</p>
        <p>Location: Toronto, Canada</p>
      </section>

      <Footer />
    </div>
  );
}

export default Home;

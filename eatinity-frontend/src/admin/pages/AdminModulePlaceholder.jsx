function AdminModulePlaceholder({ title, description }) {
  return (
    <section className="admin-dashboard">
      <p className="admin-eyebrow">Eatinity Administration</p>
      <h1>{title}</h1>
      <div className="admin-module-card admin-placeholder-card">
        <p>{description}</p>
        <span>This module will be implemented in a dedicated part.</span>
      </div>
    </section>
  );
}

export default AdminModulePlaceholder;

const money = (value) => new Intl.NumberFormat("en-CA", {
  style: "currency", currency: "CAD", maximumFractionDigits: 0,
}).format(Number(value || 0));

function SalesBarChart({ series, selectedLabel, onSelect }) {
  const maximum = Math.max(...series.map((item) => Number(item.sales || 0)), 1);

  return (
    <section className="admin-report-panel">
      <h2>Sales over time</h2>
      {series.length ? <div className="sales-chart" role="img" aria-label="Sales over time bar chart">
        {series.map((item) => {
          const height = Math.max((Number(item.sales || 0) / maximum) * 100, 3);
          return <button type="button" className={`sales-chart-column${selectedLabel === item.label ? " selected" : ""}`} key={item.label} title={`Show details for ${item.label}: ${money(item.sales)}`} aria-pressed={selectedLabel === item.label} onClick={() => onSelect(item.label)}>
            <span>{money(item.sales)}</span>
            <div className="sales-chart-track"><div className="sales-chart-bar" style={{ height: `${height}%` }} /></div>
            <small>{item.label}</small>
          </button>;
        })}
      </div> : <p>No paid sales were found for this period.</p>}
    </section>
  );
}

export default SalesBarChart;

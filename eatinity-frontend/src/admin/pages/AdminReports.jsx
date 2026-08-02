import { useEffect, useState } from "react";
import { fetchSalesReport } from "../api/salesReportsApi";
import SalesBarChart from "../components/SalesBarChart";

const PERIODS = [
  { value: "today", label: "Today" },
  { value: "daily", label: "Daily" },
  { value: "weekly", label: "Weekly" },
  { value: "monthly", label: "Monthly" },
  { value: "custom", label: "Custom" },
];

const formatMoney = (value) => new Intl.NumberFormat("en-CA", { style: "currency", currency: "CAD" }).format(Number(value || 0));
const torontoDate = (date = new Date()) => new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/Toronto", year: "numeric", month: "2-digit", day: "2-digit",
}).format(date);

function csvCell(value) {
  return `"${String(value ?? "").replaceAll('"', '""')}"`;
}

function downloadReport(report) {
  const rows = [
    ["Eatinity Sales Report"],
    ["Period", report.period], ["Start", report.startDate], ["End", report.endDate],
    ["Timezone", report.timezone], [],
    ["Metric", "Value"],
    ["Gross Sales", report.summary.grossSales], ["Subtotal", report.summary.subtotal],
    ["Tax Collected", report.summary.taxCollected], ["Paid Orders", report.summary.paidOrderCount],
    ["Average Order Value", report.summary.averageOrderValue], ["Items Sold", report.summary.itemsSold],
    [], ["Product", "Quantity", "Sales"],
    ...report.products.map((item) => [item.name, item.quantity, item.sales]),
    [], ["Time", "Sales", "Orders", "Items"],
    ...report.series.map((item) => [item.label, item.sales, item.orders, item.items]),
  ];
  const csv = rows.map((row) => row.map(csvCell).join(",")).join("\n");
  const url = URL.createObjectURL(new Blob([csv], { type: "text/csv;charset=utf-8" }));
  const link = document.createElement("a");
  link.href = url;
  link.download = `eatinity-sales-${report.startDate}-${report.endDate}.csv`;
  link.click();
  URL.revokeObjectURL(url);
}

function AdminReports() {
  const today = torontoDate();
  const monthAgo = new Date();
  monthAgo.setDate(monthAgo.getDate() - 30);
  const [period, setPeriod] = useState("today");
  const [startDate, setStartDate] = useState(torontoDate(monthAgo));
  const [endDate, setEndDate] = useState(today);
  const [report, setReport] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [selectedBar, setSelectedBar] = useState("");

  useEffect(() => {
    let active = true;
    fetchSalesReport({ period: "today" })
      .then((data) => { if (active) setReport(data); })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const loadReport = async (selectedPeriod = period) => {
    setPeriod(selectedPeriod); setLoading(true); setError(""); setSelectedBar("");
    try {
      const parameters = { period: selectedPeriod };
      if (selectedPeriod === "custom") { parameters.startDate = startDate; parameters.endDate = endDate; }
      setReport(await fetchSalesReport(parameters));
    } catch (requestError) { setError(requestError.message); }
    finally { setLoading(false); }
  };

  const summaryCards = report ? [
    ["Gross Sales", formatMoney(report.summary.grossSales)],
    ["Paid Orders", report.summary.paidOrderCount],
    ["Average Order", formatMoney(report.summary.averageOrderValue)],
    ["Tax Collected", formatMoney(report.summary.taxCollected)],
    ["Items Sold", report.summary.itemsSold],
  ] : [];
  const selectedBucket = report?.series?.find((item) => item.label === selectedBar);
  const productRows = selectedBucket ? selectedBucket.products || [] : report?.products || [];
  const deliveryRows = selectedBucket ? selectedBucket.deliveryMethods || [] : report?.deliveryMethods || [];

  return (
    <section className="admin-dashboard">
      <div className="admin-page-title">
        <div><p className="admin-eyebrow">Eatinity Administration</p><h1>Sales Reports</h1></div>
        {report && <button className="admin-button secondary" onClick={() => downloadReport(report)}>Export CSV</button>}
      </div>

      <div className="admin-report-controls">
        <div className="admin-tabs report-periods">{PERIODS.map((item) => <button className={period === item.value ? "active" : ""} key={item.value} onClick={() => item.value === "custom" ? setPeriod("custom") : loadReport(item.value)}>{item.label}</button>)}</div>
        {period === "custom" && <form className="admin-custom-dates" onSubmit={(event) => { event.preventDefault(); loadReport("custom"); }}>
          <label>Start<input type="date" required value={startDate} max={endDate} onChange={(event) => setStartDate(event.target.value)} /></label>
          <label>End<input type="date" required value={endDate} min={startDate} max={today} onChange={(event) => setEndDate(event.target.value)} /></label>
          <button className="admin-button primary" type="submit">Run Report</button>
        </form>}
      </div>

      {error && <div className="admin-alert error">{error}</div>}
      {loading ? <p>Generating sales report...</p> : report && <>
        <p className="admin-report-range">{report.startDate} to {report.endDate} · {report.timezone}</p>
        <div className="admin-summary-cards">{summaryCards.map(([label, value]) => <article key={label}><span>{label}</span><strong>{value}</strong></article>)}</div>
        <SalesBarChart series={report.series || []} selectedLabel={selectedBar} onSelect={(label) => setSelectedBar((current) => current === label ? "" : label)} />

        {selectedBucket && <div className="admin-selected-bar-summary">
          <div><strong>{selectedBucket.label}</strong><span>Selected period</span></div>
          <div><strong>{formatMoney(selectedBucket.sales)}</strong><span>Sales</span></div>
          <div><strong>{selectedBucket.orders}</strong><span>Paid orders</span></div>
          <div><strong>{selectedBucket.items}</strong><span>Items sold</span></div>
          <button className="admin-button secondary" type="button" onClick={() => setSelectedBar("")}>Show all</button>
        </div>}

        <div className="admin-report-grid">
          <section className="admin-report-panel"><h2>Product performance{selectedBucket ? ` — ${selectedBucket.label}` : ""}</h2><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Product</th><th>Quantity</th><th>Sales</th></tr></thead><tbody>{productRows.map((item) => <tr key={item.name}><td>{item.name}</td><td>{item.quantity}</td><td>{formatMoney(item.sales)}</td></tr>)}{!productRows.length && <tr><td colSpan="3">No product sales.</td></tr>}</tbody></table></div></section>
          <section className="admin-report-panel"><h2>Pickup vs delivery{selectedBucket ? ` — ${selectedBucket.label}` : ""}</h2><div className="admin-table-wrap"><table className="admin-table"><thead><tr><th>Method</th><th>Orders</th><th>Sales</th></tr></thead><tbody>{deliveryRows.map((item) => <tr key={item.method}><td>{item.method}</td><td>{item.orders}</td><td>{formatMoney(item.sales)}</td></tr>)}{!deliveryRows.length && <tr><td colSpan="3">No fulfilment data.</td></tr>}</tbody></table></div></section>
        </div>
      </>}
    </section>
  );
}

export default AdminReports;

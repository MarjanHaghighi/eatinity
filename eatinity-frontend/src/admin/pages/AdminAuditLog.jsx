import { useEffect, useState } from "react";
import { fetchAdminAuditLog } from "../api/adminAuditApi";

const ENTITY_TYPES = ["ORDER", "PRODUCT", "CATEGORY", "USER"];
const formatDate = (value) => value ? new Date(value).toLocaleString("en-CA", {
  year: "numeric", month: "short", day: "numeric", hour: "numeric", minute: "2-digit", second: "2-digit",
}) : "Unknown";
const prettyJson = (value) => JSON.stringify(value || {}, null, 2);

function AdminAuditLog() {
  const [entries, setEntries] = useState([]);
  const [filters, setFilters] = useState({ entityType: "", action: "", search: "" });
  const [nextCursor, setNextCursor] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");

  useEffect(() => {
    let active = true;
    fetchAdminAuditLog({ limit: 50 })
      .then((data) => { if (active) { setEntries(data.entries || []); setNextCursor(data.nextCursor || null); } })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const loadEntries = async ({ append = false, cursor = null } = {}) => {
    setLoading(true); setError("");
    try {
      const data = await fetchAdminAuditLog({ ...filters, limit: 50, cursor });
      setEntries((current) => append ? [...current, ...(data.entries || [])] : data.entries || []);
      setNextCursor(data.nextCursor || null);
    } catch (requestError) { setError(requestError.message); }
    finally { setLoading(false); }
  };

  const updateFilter = ({ target }) => setFilters((current) => ({ ...current, [target.name]: target.value }));

  return (
    <section className="admin-dashboard">
      <div className="admin-page-title"><div><p className="admin-eyebrow">Super Admin</p><h1>Audit Log</h1></div><button className="admin-button secondary" onClick={() => loadEntries()}>Refresh</button></div>
      <p className="admin-report-range">Review administrative changes to orders, products, categories, and staff.</p>
      {error && <div className="admin-alert error">{error}</div>}

      <form className="admin-filters" onSubmit={(event) => { event.preventDefault(); loadEntries(); }}>
        <input name="search" placeholder="Entity ID, actor email or action" value={filters.search} onChange={updateFilter} />
        <select name="entityType" value={filters.entityType} onChange={updateFilter}><option value="">All entity types</option>{ENTITY_TYPES.map((type) => <option key={type}>{type}</option>)}</select>
        <input name="action" placeholder="Exact action, e.g. PRODUCT_UPDATED" value={filters.action} onChange={updateFilter} />
        <button className="admin-button primary" type="submit">Apply</button>
        <button className="admin-button secondary" type="button" onClick={() => { setFilters({ entityType: "", action: "", search: "" }); }}>Clear fields</button>
      </form>

      {loading && !entries.length ? <p>Loading audit log...</p> : <div className="admin-audit-list">
        {entries.map((entry) => <article key={entry.auditId}>
          <div className="admin-audit-heading"><div><span className="admin-status available">{entry.entityType}</span><strong>{entry.action}</strong></div><time>{formatDate(entry.createdAt)}</time></div>
          <div className="admin-audit-meta"><span>Entity: <strong>{entry.entityId}</strong></span><span>Actor: <strong>{entry.actorEmail || entry.actorUserId}</strong></span></div>
          <details><summary>View before and after values</summary><div className="admin-audit-values"><div><h3>Before</h3><pre>{prettyJson(entry.oldValue)}</pre></div><div><h3>After</h3><pre>{prettyJson(entry.newValue)}</pre></div></div></details>
        </article>)}
        {!entries.length && <p>No audit entries match these filters.</p>}
      </div>}

      {nextCursor && <button className="admin-button secondary admin-load-more" disabled={loading} onClick={() => loadEntries({ append: true, cursor: nextCursor })}>{loading ? "Loading..." : "Load More"}</button>}
    </section>
  );
}

export default AdminAuditLog;

import { useEffect, useState } from "react";
import { useAuth } from "../../auth/AuthContext";
import {
  changeAdminStaffRole, createAdminStaff, fetchAdminUsers,
  resetAdminUserPassword, setAdminUserEnabled,
} from "../api/adminUsersApi";
import StaffForm from "../components/StaffForm";

const STAFF_ROLES = ["super-admin", "admin", "manager", "kitchen"];
const formatDate = (value) => value ? new Date(value).toLocaleDateString("en-CA", { year: "numeric", month: "short", day: "numeric" }) : "Unknown";
const displayRole = (role) => role ? role.replace("-", " ") : "Customer";

function AdminUsers() {
  const { user: currentUser, hasGroup } = useAuth();
  const isSuperAdmin = hasGroup("super-admin");
  const [tab, setTab] = useState("customer");
  const [users, setUsers] = useState([]);
  const [search, setSearch] = useState("");
  const [showStaffForm, setShowStaffForm] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    let active = true;
    fetchAdminUsers({ accountType: "customer" })
      .then((data) => { if (active) setUsers(data); })
      .catch((requestError) => { if (active) setError(requestError.message); })
      .finally(() => { if (active) setLoading(false); });
    return () => { active = false; };
  }, []);

  const loadUsers = async (accountType = tab, searchValue = search) => {
    setLoading(true); setError("");
    try { setUsers(await fetchAdminUsers({ accountType, search: searchValue })); }
    catch (requestError) { setError(requestError.message); }
    finally { setLoading(false); }
  };

  const changeTab = (accountType) => {
    setTab(accountType); setSearch(""); setShowStaffForm(false);
    loadUsers(accountType, "");
  };

  const submitSearch = (event) => { event.preventDefault(); loadUsers(); };

  const runAction = async (action, successMessage) => {
    setSaving(true); setError(""); setMessage("");
    try { await action(); await loadUsers(); setMessage(successMessage); setShowStaffForm(false); }
    catch (actionError) { setError(actionError.message); }
    finally { setSaving(false); }
  };

  const createStaff = (staff) => runAction(() => createAdminStaff(staff), "Staff invitation sent.");
  const changeRole = (account, role) => {
    if (window.confirm(`Change ${account.name || account.email} to ${displayRole(role)}?`)) {
      runAction(() => changeAdminStaffRole(account.username, role), "Staff role updated.");
    }
  };
  const toggleEnabled = (account) => {
    const action = account.enabled ? "disable" : "enable";
    if (window.confirm(`${action[0].toUpperCase()}${action.slice(1)} ${account.name || account.email}?`)) {
      runAction(() => setAdminUserEnabled(account.username, !account.enabled), `Account ${action}d.`);
    }
  };
  const resetPassword = (account) => {
    if (window.confirm(`Send a password-reset message to ${account.email}?`)) {
      runAction(() => resetAdminUserPassword(account.username), "Password-reset message requested.");
    }
  };

  return (
    <section className="admin-dashboard">
      <div className="admin-page-title">
        <div><p className="admin-eyebrow">Eatinity Administration</p><h1>Users & Staff</h1></div>
        {isSuperAdmin && tab === "staff" && <button className="admin-button primary" onClick={() => setShowStaffForm(true)}>Invite Staff</button>}
      </div>
      {error && <div className="admin-alert error">{error}</div>}{message && <div className="admin-alert success">{message}</div>}

      <div className="admin-tabs">
        <button className={tab === "customer" ? "active" : ""} onClick={() => changeTab("customer")}>Customers</button>
        <button className={tab === "staff" ? "active" : ""} onClick={() => changeTab("staff")}>Staff & Roles</button>
      </div>

      {showStaffForm && <StaffForm saving={saving} onCancel={() => setShowStaffForm(false)} onSave={createStaff} />}

      <form className="admin-filters" onSubmit={submitSearch}>
        <input aria-label="Search users" placeholder="Search name, email, phone or ID" value={search} onChange={(event) => setSearch(event.target.value)} />
        <button className="admin-button primary" type="submit">Search</button>
        <button className="admin-button secondary" type="button" onClick={() => { setSearch(""); loadUsers(tab, ""); }}>Clear</button>
      </form>

      {loading ? <p>Loading users...</p> : <div className="admin-table-wrap"><table className="admin-table">
        <thead><tr><th>User</th><th>Contact</th><th>Type / Role</th><th>Cognito Status</th><th>Created</th>{isSuperAdmin && tab === "staff" && <th>Actions</th>}</tr></thead>
        <tbody>
          {users.map((account) => {
            const role = STAFF_ROLES.find((item) => account.groups?.includes(item));
            const isSelf = account.userId === currentUser?.userId;
            return <tr key={account.username}>
              <td><strong>{account.name || "No name"}</strong><small>{account.userId}</small></td>
              <td>{account.email}<small>{account.phone || "No phone"}</small></td>
              <td><span className="admin-status available">{displayRole(role)}</span>{account.jobTitle && <small>{account.jobTitle}</small>}</td>
              <td><span className={`admin-status ${account.enabled ? "available" : "archived"}`}>{account.enabled ? account.status : "Disabled"}</span></td>
              <td>{formatDate(account.createdAt)}</td>
              {isSuperAdmin && tab === "staff" && <td className="admin-user-actions">
                {isSelf ? <small>Your account is protected.</small> : <>
                  <select aria-label={`Role for ${account.email}`} value={role || "manager"} disabled={saving} onChange={(event) => changeRole(account, event.target.value)}>{STAFF_ROLES.map((item) => <option key={item} value={item}>{displayRole(item)}</option>)}</select>
                  <button className="admin-button secondary" disabled={saving} onClick={() => toggleEnabled(account)}>{account.enabled ? "Disable" : "Enable"}</button>
                  <button className="admin-button secondary" disabled={saving || !account.enabled} onClick={() => resetPassword(account)}>Reset Password</button>
                </>}
              </td>}
            </tr>;
          })}
          {!users.length && <tr><td colSpan={isSuperAdmin && tab === "staff" ? 6 : 5}>No {tab === "staff" ? "staff members" : "customers"} found.</td></tr>}
        </tbody>
      </table></div>}
    </section>
  );
}

export default AdminUsers;

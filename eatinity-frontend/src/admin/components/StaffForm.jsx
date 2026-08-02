import { useState } from "react";

const EMPTY_STAFF = { name: "", email: "", jobTitle: "", role: "manager" };

function StaffForm({ saving, onCancel, onSave }) {
  const [form, setForm] = useState(EMPTY_STAFF);
  const updateField = ({ target }) => setForm((current) => ({ ...current, [target.name]: target.value }));
  const submit = (event) => { event.preventDefault(); onSave(form); };

  return (
    <form className="admin-form" onSubmit={submit}>
      <div className="admin-form-header"><h2>Invite Staff Member</h2><button className="admin-button secondary" type="button" onClick={onCancel}>Close</button></div>
      <p className="admin-form-help">Cognito will email a temporary password to the staff member.</p>
      <div className="admin-form-grid">
        <label>Full name<input name="name" required value={form.name} onChange={updateField} /></label>
        <label>Email<input name="email" type="email" required value={form.email} onChange={updateField} /></label>
        <label>Job title<input name="jobTitle" placeholder="Restaurant Manager" value={form.jobTitle} onChange={updateField} /></label>
        <label>Role<select name="role" value={form.role} onChange={updateField}><option value="manager">Manager</option><option value="kitchen">Kitchen</option><option value="admin">Admin</option><option value="super-admin">Super Admin</option></select></label>
      </div>
      <button className="admin-button primary admin-form-submit" disabled={saving} type="submit">{saving ? "Sending invitation..." : "Create Staff & Send Invitation"}</button>
    </form>
  );
}

export default StaffForm;

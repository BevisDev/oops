import { recipientGroups } from '../data/mock'

export function RecipientsPage() {
  return (
    <>
      <header className="page-head">
        <h1>Recipients</h1>
        <p>Groups attached to routing rules. Addresses are typed by channel (email, teams://…, URL).</p>
      </header>

      <div className="toolbar">
        <button type="button" className="btn">New group</button>
        <button type="button" className="btn ghost">Add recipient</button>
      </div>

      <div className="grid-2">
        {recipientGroups.map((g) => (
          <div className="panel" key={g.code}>
            <h3>
              {g.name} <span className="mono" style={{ color: 'var(--ink-muted)', fontWeight: 400 }}>({g.code})</span>
            </h3>
            <ul style={{ margin: 0, paddingLeft: '1.1rem', color: 'var(--ink-muted)' }}>
              {g.members.map((m) => (
                <li key={m} className="mono" style={{ marginBottom: '0.35rem', color: 'var(--ink)' }}>
                  {m}
                </li>
              ))}
            </ul>
          </div>
        ))}
      </div>
    </>
  )
}

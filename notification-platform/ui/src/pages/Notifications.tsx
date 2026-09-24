import { useState } from 'react'
import { notifications } from '../data/mock'

export function NotificationsPage() {
  const [copied, setCopied] = useState<string | null>(null)
  const [selected, setSelected] = useState(notifications[0].id)
  const n = notifications.find((x) => x.id === selected) ?? notifications[0]

  function copyUuid(id: string) {
    void navigator.clipboard?.writeText(id)
    setCopied(id)
    window.setTimeout(() => setCopied(null), 1600)
  }

  const curl = `curl -X POST $NOTIF_URL/notification/notify \\
  -H "X-Api-Key: $KEY" \\
  -H "Content-Type: application/json" \\
  -d '{"notification_id":"${n.id}","payload":{}}'`

  return (
    <>
      <header className="page-head">
        <h1>Notifications</h1>
        <p>
          Đơn vị cấu hình trên portal. Service chỉ truyền <span className="mono">notification_id</span> (UUID) —
          template, channel, recipient quản lý tại đây.
        </p>
      </header>

      <div className="toolbar">
        <button type="button" className="btn">
          New notification
        </button>
      </div>

      <div className="split">
        <section>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Severity</th>
                  <th>Channels</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {notifications.map((row) => (
                  <tr
                    key={row.id}
                    onClick={() => setSelected(row.id)}
                    style={{
                      cursor: 'pointer',
                      background: row.id === selected ? 'rgba(45,212,191,0.08)' : undefined,
                    }}
                  >
                    <td className="mono">{row.code}</td>
                    <td>{row.severity}</td>
                    <td>{row.channels.join(', ')}</td>
                    <td>
                      <span className={`badge ${row.status === 'active' ? 'ok' : 'warn'}`}>{row.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section>
          <div className="panel">
            <h3>{n.name}</h3>
            <div className="field" style={{ marginBottom: '0.85rem' }}>
              <label>UUID · service truyền field này</label>
              <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <input readOnly value={n.id} className="mono" style={{ flex: 1 }} />
                <button type="button" className="btn" onClick={() => copyUuid(n.id)}>
                  {copied === n.id ? 'Copied' : 'Copy UUID'}
                </button>
              </div>
            </div>

            <div className="grid-2" style={{ marginBottom: '0.85rem' }}>
              <div className="field">
                <label>Template</label>
                <input readOnly value={n.template} className="mono" />
              </div>
              <div className="field">
                <label>Recipient group</label>
                <input readOnly value={n.group} />
              </div>
              <div className="field">
                <label>Channels</label>
                <input readOnly value={n.channels.join(', ')} />
              </div>
              <div className="field">
                <label>Allowed sources</label>
                <input readOnly value={n.allowedSources.join(', ')} />
              </div>
            </div>

            <div className="field">
              <label>Sample curl</label>
              <textarea readOnly value={curl} rows={5} />
            </div>
          </div>
        </section>
      </div>
    </>
  )
}

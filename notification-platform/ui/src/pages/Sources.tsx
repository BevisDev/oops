import { useState } from 'react'
import { sources } from '../data/mock'

export function SourcesPage() {
  const [showKey, setShowKey] = useState(false)

  return (
    <>
      <header className="page-head">
        <h1>Sources</h1>
        <p>Systems that call <span className="mono">POST /notification/notify</span>. Each source gets API keys; source is derived from the key, not the body.</p>
      </header>

      <div className="toolbar">
        <button type="button" className="btn" onClick={() => setShowKey(true)}>
          Register source
        </button>
        <button type="button" className="btn ghost" onClick={() => setShowKey(true)}>
          Generate API key
        </button>
      </div>

      {showKey && (
        <div className="result-box" role="status">
          {`source: airflow
api_key: nh_live_8f3a9c… (shown once)
curl -H "X-Api-Key: $KEY" -X POST …/notification/notify`}
          <div className="form-actions">
            <button type="button" className="btn ghost" onClick={() => setShowKey(false)}>
              Dismiss
            </button>
          </div>
        </div>
      )}

      <section className="section">
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Code</th>
                <th>Name</th>
                <th>Owner</th>
                <th>Active</th>
                <th>Last notify</th>
              </tr>
            </thead>
            <tbody>
              {sources.map((s) => (
                <tr key={s.code}>
                  <td className="mono">{s.code}</td>
                  <td>{s.name}</td>
                  <td>{s.team}</td>
                  <td>
                    <span className={`badge ${s.active ? 'ok' : 'warn'}`}>{s.active ? 'active' : 'off'}</span>
                  </td>
                  <td className="mono">{s.lastNotify}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}

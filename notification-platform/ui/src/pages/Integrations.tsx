import { integrations } from '../data/mock'

export function IntegrationsPage() {
  return (
    <>
      <header className="page-head">
        <h1>Integrations</h1>
        <p>
          Notify through other services via channel type <span className="mono">webhook</span>. Map NotifyHub fields
          to the downstream contract.
        </p>
      </header>

      <div className="toolbar">
        <button type="button" className="btn">Add integration</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Code</th>
              <th>Name</th>
              <th>Endpoint</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {integrations.map((i) => (
              <tr key={i.code}>
                <td className="mono">{i.code}</td>
                <td>{i.name}</td>
                <td className="mono">{i.endpoint}</td>
                <td>
                  <span className={`badge ${i.active ? 'ok' : 'warn'}`}>{i.active ? 'active' : 'disabled'}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>

      <section className="section">
        <div className="section-head">
          <h2>Request mapping example</h2>
          <span>service_integrations.request_mapping</span>
        </div>
        <div className="panel">
          <pre className="mono" style={{ margin: 0, whiteSpace: 'pre-wrap', fontSize: '0.82rem', lineHeight: 1.5 }}>
{`{
  "summary": "{{payload.service}} SLA breach",
  "severity": "{{severity}}",
  "source": "{{source_system}}",
  "custom_details": {
    "metric": "{{payload.metric}}",
    "value": "{{payload.value}}",
    "threshold": "{{payload.threshold}}"
  }
}`}
          </pre>
        </div>
      </section>
    </>
  )
}

import { routingRules } from '../data/mock'

export function RoutingPage() {
  return (
    <>
      <header className="page-head">
        <h1>Routing</h1>
        <p>
          Match <span className="mono">(source, event_type, severity)</span> → template + channels + recipient group.
          Lower priority wins.
        </p>
      </header>

      <div className="toolbar">
        <button type="button" className="btn">New rule</button>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Priority</th>
              <th>Code</th>
              <th>Source</th>
              <th>Event</th>
              <th>Sev ≥</th>
              <th>Template</th>
              <th>Channels</th>
              <th>Group</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            {routingRules.map((r) => (
              <tr key={r.code}>
                <td className="mono">{r.priority}</td>
                <td className="mono">{r.code}</td>
                <td>
                  <span className="badge brand">{r.source}</span>
                </td>
                <td className="mono">{r.event}</td>
                <td>{r.severity}</td>
                <td className="mono">{r.template}</td>
                <td>{r.channels.join(', ')}</td>
                <td>{r.group}</td>
                <td>
                  <span className="badge ok">{r.status}</span>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

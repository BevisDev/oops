import { useMemo, useState } from 'react'
import { deliveries } from '../data/mock'

export function LogsPage() {
  const [source, setSource] = useState('all')
  const [status, setStatus] = useState('all')

  const rows = useMemo(
    () =>
      deliveries.filter(
        (d) => (source === 'all' || d.source === source) && (status === 'all' || d.status === status),
      ),
    [source, status],
  )

  return (
    <>
      <header className="page-head">
        <h1>Logs</h1>
        <p>Audit trail of <span className="mono">notification_requests</span> and per-channel deliveries.</p>
      </header>

      <div className="toolbar">
        <div className="field">
          <label>Source</label>
          <select value={source} onChange={(e) => setSource(e.target.value)}>
            <option value="all">all</option>
            <option value="airflow">airflow</option>
            <option value="etl">etl</option>
            <option value="de">de</option>
            <option value="core">core</option>
          </select>
        </div>
        <div className="field">
          <label>Status</label>
          <select value={status} onChange={(e) => setStatus(e.target.value)}>
            <option value="all">all</option>
            <option value="sent">sent</option>
            <option value="failed">failed</option>
          </select>
        </div>
      </div>

      <div className="table-wrap">
        <table>
          <thead>
            <tr>
              <th>Delivery</th>
              <th>Request</th>
              <th>Source</th>
              <th>Event</th>
              <th>Channel</th>
              <th>Recipient</th>
              <th>Status</th>
              <th>At</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((d) => (
              <tr key={d.id}>
                <td className="mono">{d.id}</td>
                <td className="mono">{d.request}</td>
                <td>
                  <span className="badge brand">{d.source}</span>
                </td>
                <td className="mono">{d.event}</td>
                <td>{d.channel}</td>
                <td>{d.to}</td>
                <td>
                  <span className={`badge ${d.status === 'sent' ? 'ok' : 'danger'}`}>{d.status}</span>
                </td>
                <td className="mono">{d.at}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  )
}

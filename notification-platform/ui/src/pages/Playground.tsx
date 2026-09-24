import { useState, type FormEvent } from 'react'
import { notifications } from '../data/mock'

const defaultPayload = `{
  "dag_id": "shop_etl",
  "run_id": "manual__2026-09-24T01:00:00+00:00",
  "logical_date": "2026-09-24",
  "error": "Task extract_orders failed: timeout",
  "log_url": "https://airflow.company.com/dags/shop_etl/grid",
  "env": "prod"
}`

export function PlaygroundPage() {
  const active = notifications.filter((n) => n.status === 'active')
  const [notificationId, setNotificationId] = useState(active[0]?.id ?? notifications[0].id)
  const [payload, setPayload] = useState(defaultPayload)
  const [result, setResult] = useState<string | null>(null)

  const selected = notifications.find((n) => n.id === notificationId)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    let parsed: unknown
    try {
      parsed = JSON.parse(payload)
    } catch {
      setResult('Invalid JSON payload')
      return
    }
    if (!selected || selected.status !== 'active') {
      setResult('Notification must be active')
      return
    }
    const requestId = crypto.randomUUID()
    setResult(
      JSON.stringify(
        {
          endpoint: 'POST /notification/notify',
          status: 202,
          body: {
            request_id: requestId,
            status: 'queued',
            notification_id: selected.id,
            notification_code: selected.code,
            channels: selected.channels,
            kafka_topic: 'notification.events',
            payload: parsed,
          },
        },
        null,
        2,
      ),
    )
  }

  return (
    <>
      <header className="page-head">
        <h1>Playground</h1>
        <p>
          Giống service gọi thật: chỉ chọn <span className="mono">notification_id</span> + payload. Channel/template lấy từ
          portal.
        </p>
      </header>

      <form className="panel" onSubmit={onSubmit}>
        <div className="field">
          <label>notification_id</label>
          <select value={notificationId} onChange={(e) => setNotificationId(e.target.value)}>
            {notifications.map((n) => (
              <option key={n.id} value={n.id} disabled={n.status !== 'active'}>
                {n.code} · {n.id} {n.status !== 'active' ? `(${n.status})` : ''}
              </option>
            ))}
          </select>
        </div>
        {selected && (
          <p className="empty-hint" style={{ marginTop: '0.5rem' }}>
            → {selected.channels.join(' + ')} · group {selected.group} · template {selected.template}
          </p>
        )}
        <div className="field" style={{ marginTop: '1rem' }}>
          <label>Payload JSON (template variables only)</label>
          <textarea value={payload} onChange={(e) => setPayload(e.target.value)} rows={12} />
        </div>
        <div className="form-actions">
          <button type="submit" className="btn">
            Send notify
          </button>
        </div>
      </form>

      {result && (
        <div className="result-box" role="status">
          {result}
        </div>
      )}
    </>
  )
}

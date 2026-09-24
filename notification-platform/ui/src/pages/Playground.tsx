import { useState, type FormEvent } from 'react'
import { sources } from '../data/mock'

const defaultPayload = `{
  "dag_id": "shop_etl",
  "run_id": "manual__2026-09-24T01:00:00+00:00",
  "logical_date": "2026-09-24",
  "error": "Task extract_orders failed: timeout",
  "log_url": "https://airflow.company.com/dags/shop_etl/grid",
  "env": "prod"
}`

export function PlaygroundPage() {
  const [source, setSource] = useState('airflow')
  const [eventType, setEventType] = useState('dag.failed')
  const [severity, setSeverity] = useState('error')
  const [payload, setPayload] = useState(defaultPayload)
  const [result, setResult] = useState<string | null>(null)

  function onSubmit(e: FormEvent) {
    e.preventDefault()
    let parsed: unknown
    try {
      parsed = JSON.parse(payload)
    } catch {
      setResult('Invalid JSON payload')
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
            source_system: source,
            event_type: eventType,
            severity,
            matched_rule: source === 'airflow' ? 'airflow-dag-failed-prod' : null,
            channels: ['email', 'msteams'],
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
        <p>Simulate a source calling notify. In production this publishes to Kafka; here we show the accepted envelope.</p>
      </header>

      <form className="panel" onSubmit={onSubmit}>
        <div className="grid-3">
          <div className="field">
            <label>Source</label>
            <select value={source} onChange={(e) => setSource(e.target.value)}>
              {sources.map((s) => (
                <option key={s.code} value={s.code}>
                  {s.code}
                </option>
              ))}
            </select>
          </div>
          <div className="field">
            <label>Event type</label>
            <input value={eventType} onChange={(e) => setEventType(e.target.value)} />
          </div>
          <div className="field">
            <label>Severity</label>
            <select value={severity} onChange={(e) => setSeverity(e.target.value)}>
              <option value="info">info</option>
              <option value="warning">warning</option>
              <option value="error">error</option>
              <option value="critical">critical</option>
            </select>
          </div>
        </div>
        <div className="field" style={{ marginTop: '1rem' }}>
          <label>Payload JSON</label>
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

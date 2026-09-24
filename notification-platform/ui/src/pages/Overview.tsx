import { useEffect, useState } from 'react'
import { overview, deliveries } from '../data/mock'

function useCountUp(target: number, duration = 700) {
  const [value, setValue] = useState(0)
  useEffect(() => {
    let raf = 0
    const start = performance.now()
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration)
      const eased = 1 - (1 - t) ** 3
      setValue(Math.round(target * eased))
      if (t < 1) raf = requestAnimationFrame(tick)
    }
    raf = requestAnimationFrame(tick)
    return () => cancelAnimationFrame(raf)
  }, [target, duration])
  return value
}

export function OverviewPage() {
  const sent = useCountUp(overview.sent24h)
  const failed = useCountUp(overview.failed24h)
  const latency = useCountUp(overview.avgLatencyMs)
  const maxSpark = Math.max(...overview.spark)

  return (
    <>
      <header className="page-head">
        <h1>NotifyHub</h1>
        <p>
          Central bus for Airflow, ETL, DE, and Core — templates on UI, delivery via Email, MS Teams,
          and HTTP services.
        </p>
      </header>

      <div className="metrics">
        <div className="metric">
          <div className="label">Sent · 24h</div>
          <div className="value">{sent.toLocaleString()}</div>
          <div className="hint">Across all source systems</div>
        </div>
        <div className="metric">
          <div className="label">Failed · 24h</div>
          <div className="value" style={{ color: 'var(--danger)' }}>
            {failed}
          </div>
          <div className="hint">0.9% error rate</div>
        </div>
        <div className="metric">
          <div className="label">Avg latency</div>
          <div className="value">
            {latency}
            <span style={{ fontSize: '1rem', color: 'var(--ink-muted)' }}> ms</span>
          </div>
          <div className="hint">Ingest → first delivery attempt</div>
        </div>
      </div>

      <div className="split">
        <section className="section" style={{ marginTop: 0 }}>
          <div className="section-head">
            <h2>Volume by channel</h2>
            <span>last 24 hours</span>
          </div>
          <div className="panel">
            <div className="channel-bars">
              {overview.byChannel.map((c) => (
                <div className="channel-bar" key={c.channel}>
                  <span className="mono">{c.channel}</span>
                  <div className="track">
                    <div
                      className={`fill ${c.channel === 'msteams' ? 'teams' : c.channel === 'webhook' ? 'webhook' : ''}`}
                      style={{ width: `${c.pct}%` }}
                    />
                  </div>
                  <span className="mono">{c.count}</span>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="section" style={{ marginTop: 0 }}>
          <div className="section-head">
            <h2>Hourly throughput</h2>
            <span>spark · UTC</span>
          </div>
          <div className="panel">
            <div className="spark" aria-hidden>
              {overview.spark.map((n, i) => (
                <span
                  key={i}
                  style={{
                    height: `${(n / maxSpark) * 100}%`,
                    animationDelay: `${i * 0.02}s`,
                    opacity: 0.35 + (n / maxSpark) * 0.65,
                  }}
                />
              ))}
            </div>
          </div>
        </section>
      </div>

      <section className="section">
        <div className="section-head">
          <h2>Recent deliveries</h2>
          <span>live sample data</span>
        </div>
        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Time</th>
                <th>Source</th>
                <th>Event</th>
                <th>Channel</th>
                <th>To</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {deliveries.slice(0, 5).map((d) => (
                <tr key={d.id}>
                  <td className="mono">{d.at}</td>
                  <td>
                    <span className="badge brand">{d.source}</span>
                  </td>
                  <td className="mono">{d.event}</td>
                  <td>{d.channel}</td>
                  <td>{d.to}</td>
                  <td>
                    <span className={`badge ${d.status === 'sent' ? 'ok' : 'danger'}`}>{d.status}</span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </>
  )
}

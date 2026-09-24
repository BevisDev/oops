import { useState } from 'react'
import { templates, sampleTemplateBodies } from '../data/mock'

type Tab = 'email' | 'msteams' | 'webhook'

export function TemplatesPage() {
  const [selected, setSelected] = useState(templates[0].code)
  const [tab, setTab] = useState<Tab>('email')
  const tpl = templates.find((t) => t.code === selected) ?? templates[0]

  const body =
    tab === 'email'
      ? `${sampleTemplateBodies.emailSubject}\n\n${sampleTemplateBodies.emailHtml}`
      : tab === 'msteams'
        ? sampleTemplateBodies.teamsCard
        : sampleTemplateBodies.webhookBody

  return (
    <>
      <header className="page-head">
        <h1>Templates</h1>
        <p>Versioned bodies per channel. Variables come from the notify <span className="mono">payload</span>; schema is validated on ingest.</p>
      </header>

      <div className="split">
        <section>
          <div className="section-head">
            <h2>Library</h2>
            <button type="button" className="btn">New template</button>
          </div>
          <div className="table-wrap">
            <table>
              <thead>
                <tr>
                  <th>Code</th>
                  <th>Source</th>
                  <th>Ver</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {templates.map((t) => (
                  <tr
                    key={t.code}
                    onClick={() => setSelected(t.code)}
                    style={{ cursor: 'pointer', background: t.code === selected ? 'rgba(45,212,191,0.08)' : undefined }}
                  >
                    <td className="mono">{t.code}</td>
                    <td>{t.source}</td>
                    <td className="mono">v{t.version}</td>
                    <td>
                      <span className={`badge ${t.status === 'active' ? 'ok' : 'warn'}`}>{t.status}</span>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </section>

        <section>
          <div className="section-head">
            <h2>{tpl.name}</h2>
            <span className="mono">{tpl.code}</span>
          </div>
          <div className="panel">
            <div className="tabs">
              {(['email', 'msteams', 'webhook'] as Tab[]).map((t) => (
                <button key={t} type="button" className={tab === t ? 'active' : ''} onClick={() => setTab(t)}>
                  {t}
                </button>
              ))}
            </div>
            <div className="preview-pane" key={tab}>
              <div className="field">
                <label>Body · {tab}</label>
                <textarea readOnly value={body} rows={14} />
              </div>
              <div className="form-actions">
                <button type="button" className="btn">Publish version</button>
                <button type="button" className="btn ghost">Preview render</button>
              </div>
            </div>
          </div>
        </section>
      </div>
    </>
  )
}

import { channelEndpoints } from '../data/mock'

const groups = [
  { type: 'email', title: 'Email', blurb: 'SMTP / SES endpoints used by the email adapter.' },
  { type: 'msteams', title: 'Microsoft Teams', blurb: 'Incoming webhooks & Adaptive Card delivery.' },
  { type: 'webhook', title: 'HTTP services', blurb: 'Call other notify services (pager, OMS, Slack gateway).' },
] as const

export function ChannelsPage() {
  return (
    <>
      <header className="page-head">
        <h1>Channels</h1>
        <p>Delivery adapters. Add endpoints without schema changes — secrets stay in Vault via <span className="mono">secret_ref</span>.</p>
      </header>

      {groups.map((g) => {
        const rows = channelEndpoints.filter((e) => e.channel === g.type)
        return (
          <section className="section" key={g.type}>
            <div className="section-head">
              <h2>{g.title}</h2>
              <span>{g.blurb}</span>
            </div>
            <div className="table-wrap">
              <table>
                <thead>
                  <tr>
                    <th>Code</th>
                    <th>Name</th>
                    <th>Config</th>
                    <th>Default</th>
                    <th>Secret</th>
                  </tr>
                </thead>
                <tbody>
                  {rows.map((e) => (
                    <tr key={e.code}>
                      <td className="mono">{e.code}</td>
                      <td>{e.name}</td>
                      <td className="mono">{e.detail}</td>
                      <td>{e.isDefault ? <span className="badge brand">default</span> : '—'}</td>
                      <td>
                        <span className={`badge ${e.secretOk ? 'ok' : 'danger'}`}>
                          {e.secretOk ? 'vault ok' : 'missing'}
                        </span>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </section>
        )
      })}
    </>
  )
}

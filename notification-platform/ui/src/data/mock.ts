export type ChannelType = 'email' | 'msteams' | 'webhook'

export const sources = [
  { code: 'airflow', name: 'Apache Airflow', team: 'data-platform', active: true, lastNotify: '2m ago' },
  { code: 'etl', name: 'ETL Pipelines', team: 'data-engineering', active: true, lastNotify: '18m ago' },
  { code: 'de', name: 'DE Services', team: 'data-engineering', active: true, lastNotify: '1h ago' },
  { code: 'core', name: 'Core Platform', team: 'platform', active: true, lastNotify: '4h ago' },
]

export const channelEndpoints = [
  { channel: 'email' as ChannelType, code: 'smtp-primary', name: 'Primary SMTP', detail: 'smtp.company.com:587', isDefault: true, secretOk: true },
  { channel: 'msteams' as ChannelType, code: 'teams-de-alerts', name: 'DE Alerts', detail: 'Incoming webhook · vault://teams/de', isDefault: true, secretOk: true },
  { channel: 'msteams' as ChannelType, code: 'teams-core', name: 'Core Ops', detail: 'Incoming webhook · vault://teams/core', isDefault: false, secretOk: true },
  { channel: 'webhook' as ChannelType, code: 'svc-pager-bridge', name: 'Pager bridge', detail: 'POST pager-bridge.internal/v1/alert', isDefault: true, secretOk: true },
]

export const templates = [
  { code: 'airflow.dag.failed', name: 'Airflow DAG Failed', status: 'active', version: 1, channels: ['email', 'msteams'] },
  { code: 'etl.pipeline.success', name: 'ETL Pipeline Success', status: 'active', version: 2, channels: ['email'] },
  { code: 'de.sla.breach', name: 'DE SLA Breach', status: 'active', version: 3, channels: ['email', 'msteams', 'webhook'] },
  { code: 'core.fraud.suspected', name: 'Fraud Suspected', status: 'draft', version: 1, channels: ['msteams', 'webhook'] },
]

/** Portal-managed notifications — services only pass id (UUID). */
export const notifications = [
  {
    id: 'n1000000-0000-4000-8000-000000000001',
    code: 'airflow-dag-failed',
    name: 'Airflow DAG Failed',
    template: 'airflow.dag.failed',
    severity: 'error',
    channels: ['email', 'msteams'],
    group: 'de-oncall',
    allowedSources: ['airflow'],
    status: 'active',
  },
  {
    id: 'n2000000-0000-4000-8000-000000000002',
    code: 'etl-pipeline-success',
    name: 'ETL Pipeline Success',
    template: 'etl.pipeline.success',
    severity: 'info',
    channels: ['email'],
    group: 'de-oncall',
    allowedSources: ['etl'],
    status: 'active',
  },
  {
    id: 'n3000000-0000-4000-8000-000000000003',
    code: 'de-sla-breach',
    name: 'DE SLA Breach',
    template: 'de.sla.breach',
    severity: 'critical',
    channels: ['email', 'msteams', 'webhook'],
    group: 'de-oncall',
    allowedSources: ['de'],
    status: 'active',
  },
  {
    id: 'n4000000-0000-4000-8000-000000000004',
    code: 'core-fraud-suspected',
    name: 'Fraud Suspected',
    template: 'core.fraud.suspected',
    severity: 'warning',
    channels: ['msteams', 'webhook'],
    group: 'core-alerts',
    allowedSources: ['core'],
    status: 'draft',
  },
]

export const recipientGroups = [
  { code: 'de-oncall', name: 'DE On-call', members: ['de-oncall@company.com', 'teams://channel/de-alerts'] },
  { code: 'core-alerts', name: 'Core Alerts', members: ['platform@company.com'] },
]

export const integrations = [
  { code: 'pagerduty-bridge', name: 'PagerDuty Bridge', endpoint: 'svc-pager-bridge', active: true },
  { code: 'oms-alert', name: 'OMS Alert Service', endpoint: 'svc-pager-bridge', active: false },
]

export const deliveries = [
  { id: 'del_8f2a', request: 'req_91c0', notificationId: 'n1000000-…0001', code: 'airflow-dag-failed', source: 'airflow', channel: 'msteams', to: 'DE Alerts', status: 'sent', at: '14:12:03' },
  { id: 'del_8f2b', request: 'req_91c0', notificationId: 'n1000000-…0001', code: 'airflow-dag-failed', source: 'airflow', channel: 'email', to: 'de-oncall@…', status: 'sent', at: '14:12:04' },
  { id: 'del_7aa1', request: 'req_88b1', notificationId: 'n3000000-…0003', code: 'de-sla-breach', source: 'de', channel: 'webhook', to: 'pager-bridge', status: 'failed', at: '13:41:22' },
  { id: 'del_6c10', request: 'req_77a2', notificationId: 'n2000000-…0002', code: 'etl-pipeline-success', source: 'etl', channel: 'email', to: 'de-oncall@…', status: 'sent', at: '12:05:11' },
  { id: 'del_5b09', request: 'req_66z1', notificationId: 'n4000000-…0004', code: 'core-fraud-suspected', source: 'core', channel: 'msteams', to: 'Core Ops', status: 'sent', at: '10:22:48' },
]

export const overview = {
  sent24h: 1842,
  failed24h: 17,
  avgLatencyMs: 312,
  byChannel: [
    { channel: 'email', count: 920, pct: 72 },
    { channel: 'msteams', count: 710, pct: 56 },
    { channel: 'webhook', count: 212, pct: 18 },
  ],
  spark: [12, 18, 15, 22, 30, 28, 35, 40, 38, 42, 48, 44, 50, 55, 52, 60, 58, 62, 70, 68, 72, 75, 80, 78],
}

export const sampleTemplateBodies = {
  emailSubject: '[{{env}}] DAG failed: {{dag_id}}',
  emailHtml: `<h2>DAG failed</h2>
<p><b>{{dag_id}}</b> / {{run_id}}</p>
<p>{{error}}</p>
<p><a href="{{log_url}}">View logs</a></p>`,
  teamsCard: `{
  "type": "AdaptiveCard",
  "body": [
    {
      "type": "TextBlock",
      "size": "Large",
      "weight": "Bolder",
      "text": "DAG failed: {{dag_id}}",
      "color": "Attention"
    },
    {
      "type": "FactSet",
      "facts": [
        { "title": "Run", "value": "{{run_id}}" },
        { "title": "Env", "value": "{{env}}" }
      ]
    }
  ]
}`,
  webhookBody: `{
  "notification_id": "{{notification_id}}",
  "dag_id": "{{dag_id}}",
  "error": "{{error}}"
}`,
}

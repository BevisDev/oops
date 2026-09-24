# API & Kafka contracts

Base path: `/notification`

Auth: `Authorization: Bearer <api_key>` hoặc header `X-Api-Key`.

---

## POST `/notification/notify`

Ingest một sự kiện thông báo. API validate → ghi `notification_requests` → pub Kafka → `202 Accepted`.

### Request

```json
{
  "event_type": "dag.failed",
  "severity": "error",
  "idempotency_key": "airflow:dag.failed:shop_etl:2026-09-24T01:00:00Z",
  "correlation_id": "manual__2026-09-24T01:00:00+00:00",
  "payload": {
    "dag_id": "shop_etl",
    "run_id": "manual__2026-09-24T01:00:00+00:00",
    "logical_date": "2026-09-24",
    "error": "Task extract_orders failed: timeout",
    "log_url": "https://airflow.company.com/dags/shop_etl/grid",
    "env": "prod"
  },
  "template_code": null,
  "channels": null,
  "recipients": {
    "email": ["de-oncall@company.com"],
    "msteams": []
  },
  "metadata": {
    "env": "prod",
    "region": "apse"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `event_type` | string | yes | Logical event name |
| `severity` | enum | no | `info` \| `warning` \| `error` \| `critical` |
| `payload` | object | yes | Template variables |
| `idempotency_key` | string | no | Dedupe per source (24h+) |
| `correlation_id` | string | no | Cross-system trace |
| `template_code` | string | no | Skip routing; use this template |
| `channels` | string[] | no | e.g. `["email","msteams","webhook"]` |
| `recipients` | object | no | Per-channel address lists |
| `metadata` | object | no | Free-form; usable in `match_expr` |

`source_system` được suy ra từ API key, **không** tin field từ body.

### Response `202`

```json
{
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "queued",
  "matched_rule": "airflow-dag-failed-prod",
  "channels": ["email", "msteams"]
}
```

### Errors

| Code | When |
|------|------|
| `400` | Invalid body / schema |
| `401` | Missing/invalid API key |
| `409` | Duplicate `idempotency_key` (return original `request_id`) |
| `422` | No routing rule & no `template_code` |
| `429` | Rate limited |

---

## GET `/notification/requests/{request_id}`

Chi tiết request + deliveries.

## GET `/notification/deliveries?status=&source=&from=&to=`

Search delivery logs (UI Logs screen).

## Admin CRUD (UI backend)

| Method | Path | Purpose |
|--------|------|---------|
| CRUD | `/admin/sources` | Source systems |
| CRUD | `/admin/api-clients` | API keys |
| CRUD | `/admin/channels` | Channels |
| CRUD | `/admin/channel-endpoints` | SMTP / Teams / HTTP configs |
| CRUD | `/admin/templates` | Templates |
| POST | `/admin/templates/{id}/versions` | New version |
| POST | `/admin/templates/{id}/preview` | Render preview |
| CRUD | `/admin/routing-rules` | Routing |
| CRUD | `/admin/recipient-groups` | Groups |
| CRUD | `/admin/integrations` | Other services |
| POST | `/admin/playground/notify` | Test send |

---

## Kafka — `notification.events`

### Envelope

```json
{
  "specversion": "1.0",
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "source": "notification-api",
  "type": "notification.notify.v1",
  "time": "2026-09-24T14:00:00.000Z",
  "datacontenttype": "application/json",
  "data": {
    "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
    "source_system": "airflow",
    "event_type": "dag.failed",
    "severity": "error",
    "payload": { "...": "..." },
    "routing": {
      "rule_code": "airflow-dag-failed-prod",
      "template_code": "airflow.dag.failed",
      "channels": [
        {
          "channel": "email",
          "endpoint": "smtp-primary",
          "recipient_group": "de-oncall"
        },
        {
          "channel": "msteams",
          "endpoint": "teams-de-alerts",
          "recipient_group": "de-oncall"
        }
      ]
    },
    "recipients_override": {
      "email": ["de-oncall@company.com"]
    },
    "correlation_id": "manual__2026-09-24T01:00:00+00:00",
    "metadata": { "env": "prod" }
  }
}
```

### Headers (recommended)

| Header | Value |
|--------|-------|
| `ce_type` | `notification.notify.v1` |
| `source_system` | `airflow` |
| `event_type` | `dag.failed` |
| `correlation_id` | … |

---

## Channel adapter payloads (worker → provider)

### Email

```json
{
  "from": "noreply@company.com",
  "to": ["de-oncall@company.com"],
  "subject": "[prod] DAG failed: shop_etl",
  "html": "<h2>DAG failed</h2>..."
}
```

### MS Teams (Adaptive Card)

POST tới Incoming Webhook URL (từ Vault):

```json
{
  "type": "message",
  "attachments": [
    {
      "contentType": "application/vnd.microsoft.card.adaptive",
      "content": { "...rendered adaptive card..." }
    }
  ]
}
```

### Webhook / other service

```http
POST {base_url}
Content-Type: application/json
X-Correlation-Id: {correlation_id}

{
  "event_type": "dag.failed",
  "severity": "error",
  "source_system": "airflow",
  "payload": { "...": "..." },
  "rendered": { "body": "..." }
}
```

Mapping có thể customize qua `service_integrations.request_mapping`.

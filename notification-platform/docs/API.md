# API & Kafka contracts

Base path: `/notification`

Auth: `Authorization: Bearer <api_key>` hoặc header `X-Api-Key`.

---

## Caller contract (quan trọng)

Service **chỉ truyền UUID notification** đã cấu hình trên portal.
Template, channel, recipient, severity — **không** nằm trong request.

```json
{
  "notification_id": "n1000000-0000-4000-8000-000000000001",
  "payload": { }
}
```

`payload` chỉ chứa biến động để render template (optional nếu template không cần biến).

---

## POST `/notification/notify`

Validate UUID → load portal config → ghi `notification_requests` → pub Kafka → `202`.

### Request

```json
{
  "notification_id": "n1000000-0000-4000-8000-000000000001",
  "payload": {
    "dag_id": "shop_etl",
    "run_id": "manual__2026-09-24T01:00:00+00:00",
    "logical_date": "2026-09-24",
    "error": "Task extract_orders failed: timeout",
    "log_url": "https://airflow.company.com/dags/shop_etl/grid",
    "env": "prod"
  },
  "idempotency_key": "airflow:n1000000:manual__2026-09-24T01:00:00+00:00",
  "correlation_id": "manual__2026-09-24T01:00:00+00:00"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notification_id` | UUID | **yes** | ID cấu hình trên portal |
| `payload` | object | no | Biến template (validate theo `variables_schema`) |
| `idempotency_key` | string | no | Dedupe per notification |
| `correlation_id` | string | no | Cross-system trace |

**Không** nhận: `event_type`, `channels`, `recipients`, `template_code`, `severity` — tất cả lấy từ portal.

`source_system` suy ra từ API key. Nếu notification có ACL (`notification_allowed_sources`), source phải nằm trong whitelist.

### Response `202`

```json
{
  "request_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "status": "queued",
  "notification_id": "n1000000-0000-4000-8000-000000000001",
  "notification_code": "airflow-dag-failed",
  "channels": ["email", "msteams"]
}
```

### Errors

| Code | When |
|------|------|
| `400` | Missing `notification_id` / invalid payload schema |
| `401` | Missing/invalid API key |
| `403` | Source not allowed for this notification |
| `404` | Unknown or archived notification UUID |
| `409` | Duplicate `idempotency_key` |
| `422` | Notification status ≠ `active` |
| `429` | Rate limited |

---

## GET `/notification/requests/{request_id}`

Chi tiết request + deliveries.

## GET `/notification/deliveries?notification_id=&status=&from=&to=`

Search delivery logs.

## Admin CRUD (portal)

| Method | Path | Purpose |
|--------|------|---------|
| CRUD | `/admin/notifications` | **Đơn vị chính** — UUID, targets, ACL |
| POST | `/admin/notifications/{id}/copy-uuid` | Convenience |
| CRUD | `/admin/templates` | Bodies per channel |
| CRUD | `/admin/channels` / `channel-endpoints` | SMTP / Teams / HTTP |
| CRUD | `/admin/recipient-groups` | Groups |
| CRUD | `/admin/sources` / `api-clients` | Who can call |
| CRUD | `/admin/integrations` | Other services |
| POST | `/admin/playground/notify` | Test by UUID |

---

## Kafka — `notification.events`

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
    "notification_id": "n1000000-0000-4000-8000-000000000001",
    "notification_code": "airflow-dag-failed",
    "source_system": "airflow",
    "severity": "error",
    "template_id": "a1000000-0000-4000-8000-000000000001",
    "template_version": 1,
    "payload": { "dag_id": "shop_etl", "...": "..." },
    "targets": [
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
    ],
    "correlation_id": "manual__2026-09-24T01:00:00+00:00"
  }
}
```

Worker **không** resolve routing — snapshot targets đã gắn từ portal lúc ingest (hoặc worker load lại theo `notification_id`).

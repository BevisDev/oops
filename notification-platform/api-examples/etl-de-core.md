# ETL / DE / Core — sample notify calls

## ETL pipeline success

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $ETL_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "pipeline.success",
    "severity": "info",
    "idempotency_key": "etl:pipeline.success:orders_daily:2026-09-24",
    "correlation_id": "orders_daily-2026-09-24",
    "payload": {
      "pipeline": "orders_daily",
      "rows": 1254301,
      "duration_sec": 842,
      "env": "prod"
    }
  }'
```

## DE service — SLA breach (email + teams + pager webhook)

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $DE_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "sla.breach",
    "severity": "critical",
    "payload": {
      "service": "quality-gate",
      "metric": "freshness_hours",
      "value": 26,
      "threshold": 12,
      "table": "mart.orders"
    },
    "channels": ["email", "msteams", "webhook"],
    "recipients": {
      "email": ["de-oncall@company.com"]
    }
  }'
```

## Core — call NotifyHub which fans out to another service

Khi routing rule gắn channel `webhook` → worker POST sang service khác
(ví dụ `pager-bridge`, `oms-alert`) theo `service_integrations`.

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $CORE_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "event_type": "order.fraud_suspected",
    "severity": "warning",
    "correlation_id": "ord_9f2a",
    "payload": {
      "order_id": "ord_9f2a",
      "score": 0.91,
      "customer_id": "cus_11"
    },
    "template_code": "core.fraud.suspected"
  }'
```

# ETL / DE / Core — chỉ truyền UUID

Mọi cấu hình (template, email, Teams, webhook sang service khác) nằm trên portal.
Service chỉ biết UUID đã được cấp.

## ETL

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $ETL_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "notification_id": "n2000000-0000-4000-8000-000000000002",
    "idempotency_key": "etl:orders_daily:2026-09-24",
    "payload": {
      "pipeline": "orders_daily",
      "rows": 1254301,
      "duration_sec": 842,
      "env": "prod"
    }
  }'
```

## DE — SLA (portal đã gắn email + teams + pager webhook)

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $DE_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "notification_id": "n3000000-0000-4000-8000-000000000003",
    "payload": {
      "service": "quality-gate",
      "metric": "freshness_hours",
      "value": 26,
      "threshold": 12,
      "table": "mart.orders"
    }
  }'
```

## Core

```bash
curl -sS -X POST https://notif.company.com/notification/notify \
  -H "X-Api-Key: $CORE_NOTIF_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "notification_id": "n4000000-0000-4000-8000-000000000004",
    "correlation_id": "ord_9f2a",
    "payload": {
      "order_id": "ord_9f2a",
      "score": 0.91,
      "customer_id": "cus_11"
    }
  }'
```

Muốn đổi channel / recipient / template → sửa trên portal, **không** đổi code service.

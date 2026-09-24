# Notification Platform

Centralized notification hub. **Portal owns config; services only pass a UUID.**

```
Service  →  POST /notification/notify { notification_id, payload? }
         →  Kafka  →  Worker renders portal template  →  Email / MS Teams / HTTP
```

## Layout

| Path | Purpose |
|------|---------|
| `docs/` | Design, API (UUID-first), UI, ER |
| `db/migrations/` | Postgres schema + seed (fixed sample UUID) |
| `api-examples/` | Minimal caller samples |
| `ui/` | Portal prototype |

## Sample UUID (seed)

```
n1000000-0000-4000-8000-000000000001   # airflow-dag-failed
```

## Run portal UI

```bash
cd notification-platform/ui
npm install
npm run dev
```

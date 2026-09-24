# Notification Platform

Centralized notification hub for Data Engineering & Core systems.

Sources (Airflow, ETL pipelines, DE services, Core APIs, and other services) call
`POST /notification/notify` → API publishes to Kafka → workers consume, render
templates managed on the Admin UI, and deliver via **Email**, **MS Teams**, or
**HTTP service callbacks**.

## Architecture

```
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│   Airflow    │  │  ETL / dbt   │  │  DE Service  │  │ Core / Other │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                 │                 │                 │
       └─────────────────┴────────┬────────┴─────────────────┘
                                  │  POST /notification/notify
                                  ▼
                       ┌─────────────────────┐
                       │  Notification API   │
                       │  auth · validate ·  │
                       │  resolve routing    │
                       └──────────┬──────────┘
                                  │  produce
                                  ▼
                       ┌─────────────────────┐
                       │  Kafka              │
                       │  notification.events│
                       └──────────┬──────────┘
                                  │  consume
                                  ▼
                       ┌─────────────────────┐
                       │  Notification Worker│
                       │  template render ·  │
                       │  channel adapters   │
                       └──────────┬──────────┘
              ┌───────────────────┼───────────────────┐
              ▼                   ▼                   ▼
         ┌─────────┐        ┌──────────┐       ┌─────────────┐
         │  Email  │        │ MS Teams │       │ HTTP / Other│
         │ (SMTP)  │        │ webhook  │       │   service   │
         └─────────┘        └──────────┘       └─────────────┘
                                  │
                                  ▼
                       ┌─────────────────────┐
                       │  PostgreSQL         │
                       │  templates · rules  │
                       │  delivery_logs      │
                       └─────────────────────┘
```

## Package layout

| Path | Purpose |
|------|---------|
| `docs/DESIGN.md` | Domain model, flows, extensibility |
| `docs/API.md` | REST + Kafka contracts |
| `db/migrations/` | Postgres schema (extensible) |
| `api-examples/` | Sample payloads from Airflow / DE / Core |
| `ui/` | Admin console (templates, channels, logs) |

## Quick start (UI prototype)

```bash
cd notification-platform/ui
npm install
npm run dev
```

## Design goals

1. **Multi-source** — any system registers as a `source_system` + API key.
2. **Multi-channel** — email, msteams, webhook/service; add Slack/SMS later without schema rewrite.
3. **Template-driven** — UI-managed templates with versioning & variables.
4. **Async & durable** — Kafka between ingest and delivery; retries + dead-letter.
5. **Auditable** — every notify request and delivery attempt logged.

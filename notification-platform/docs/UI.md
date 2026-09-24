# UI Design — Notification Admin

Brand: **NotifyHub**. Ops console cho Data Platform — teal/slate, typography IBM Plex,
không dùng purple gradient / cream-terracotta / broadsheet.

## Information architecture

```
NotifyHub
├── Overview          — volume, success rate, failing sources
├── Sources           — systems + API keys
├── Channels          — Email · MS Teams · HTTP Service endpoints
├── Templates         — list · editor · preview · versions
├── Routing           — event → template + channels + groups
├── Recipients        — addresses & groups
├── Integrations      — other notify services (webhook)
├── Logs              — requests & deliveries
└── Playground        — test POST /notify
```

## Screen specs

### Overview
- One job: health of the notification bus in the last 24h.
- Hero brand mark + short status line (not a marketing landing).
- Metrics as typographic figures (not card grids of fluff): Sent, Failed, Avg latency.
- Timeline spark by channel (email / msteams / webhook).
- Recent failures list (link into Logs).

### Sources
- Table: code, display name, owner team, active, last notify.
- Drawer: create source + generate API key (show once).
- Copy curl sample for that source.

### Channels
- Three sections (one job each): Email endpoints, Teams endpoints, HTTP services.
- Each endpoint: code, config summary, secret_ref status, default flag, active.
- Test connection action.

### Templates
- List filtered by source / status.
- Editor split:
  - Left: metadata + variables schema (JSON)
  - Right: tabs per channel (Email subject/HTML, Teams Adaptive Card JSON, Webhook body)
- Live preview with sample payload JSON.
- Version history sidebar; publish = bump `current_version` + set `active`.

### Routing
- Rule rows: source · event_type · severity_min · template · channels · priority · status.
- Builder form with channel multi-select + recipient group.
- Optional `match_expr` (e.g. `payload.env == "prod"`).

### Recipients
- Groups as primary; members nested.
- Add address with channel type.

### Integrations
- List of `service_integrations` linked to webhook endpoints.
- Request mapping editor (JSON) for calling other services.

### Logs
- Filters: time, source, event, channel, status.
- Detail drawer: request payload, rendered body, attempts.

### Playground
- Form mirrors `POST /notification/notify`.
- Choose source (uses its key in session) → send → show `request_id` + link to Logs.

## Motion (2–3 intentional)

1. Sidebar active indicator slides between nav items.
2. Template preview panel fades/slides when switching channel tabs.
3. Overview metric numbers count-up on first paint.

## Visual tokens

```css
--bg: #0c1413;
--bg-elevated: #14201e;
--surface: #1a2a27;
--ink: #e8f0ee;
--ink-muted: #8aa39c;
--brand: #2dd4bf;      /* teal signal */
--brand-deep: #0f766e;
--warn: #f59e0b;
--danger: #f87171;
--ok: #34d399;
--font-sans: "IBM Plex Sans", system-ui, sans-serif;
--font-mono: "IBM Plex Mono", ui-monospace, monospace;
```

Background: deep teal-black with subtle radial mesh (not flat).

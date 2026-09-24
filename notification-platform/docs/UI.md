# UI Design — NotifyHub Portal

Brand: **NotifyHub**. Portal quản lý toàn bộ cấu hình; service chỉ copy UUID.

## IA

```
NotifyHub
├── Overview
├── Notifications   ← primary: UUID + targets + ACL
├── Templates
├── Channels
├── Recipients
├── Sources
├── Integrations
├── Logs
└── Playground      ← test bằng notification_id
```

## Notifications (màn chính)

- Table: code, display name, UUID (copy), template, channels, severity, status, allowed sources.
- Detail / create:
  1. Metadata + severity + status
  2. Chọn template
  3. Targets: multi channel endpoint + recipient group (+ integration nếu webhook)
  4. Allowed sources (ACL)
  5. Variables schema preview + sample curl với UUID
- CTA nổi: **Copy UUID** / **Copy curl**

## Playground

Chỉ 2 input chính: `notification_id` (dropdown từ active notifications) + `payload` JSON.

## Visual tokens

Giữ design tokens hiện tại (teal/slate, IBM Plex). Sidebar foot: `UUID → Kafka → adapters`.

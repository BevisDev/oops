-- Notification Platform — PostgreSQL schema
-- Designed for multi-source (Airflow, ETL, DE, Core, …) and multi-channel
-- (email, msteams, webhook/service, …) with template management & audit.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ---------------------------------------------------------------------------
-- Enums (use TEXT + CHECK for easier evolution; values documented here)
-- ---------------------------------------------------------------------------
-- channel_type:     email | msteams | webhook | slack | sms
-- severity:         info | warning | error | critical
-- request_status:   accepted | rejected | queued
-- delivery_status:  pending | sending | sent | failed | skipped | dead
-- template_status:  draft | active | archived
-- rule_status:      active | disabled

-- ---------------------------------------------------------------------------
-- Source systems that may call /notification/notify
-- ---------------------------------------------------------------------------
CREATE TABLE source_systems (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,          -- e.g. airflow, etl, de, core
    display_name    TEXT NOT NULL,
    description     TEXT,
    owner_team      TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE api_clients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_system_id UUID NOT NULL REFERENCES source_systems(id) ON DELETE CASCADE,
    client_name     TEXT NOT NULL,
    -- store only hash; plaintext shown once on create
    api_key_hash    TEXT NOT NULL,
    api_key_prefix  TEXT NOT NULL,                 -- first 8 chars for lookup UI
    scopes          TEXT[] NOT NULL DEFAULT ARRAY['notify']::TEXT[],
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_system_id, client_name)
);

CREATE INDEX idx_api_clients_prefix ON api_clients(api_key_prefix);

-- ---------------------------------------------------------------------------
-- Channels & channel configs (credentials / endpoints)
-- ---------------------------------------------------------------------------
CREATE TABLE channels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,          -- email, msteams, webhook, …
    display_name    TEXT NOT NULL,
    channel_type    TEXT NOT NULL
                        CHECK (channel_type IN ('email','msteams','webhook','slack','sms')),
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Concrete connection: SMTP account, Teams incoming webhook, HTTP service URL, …
CREATE TABLE channel_endpoints (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    code            TEXT NOT NULL,                -- e.g. smtp-primary, teams-de-alerts
    display_name    TEXT NOT NULL,
    -- type-specific config (non-secret). Secrets live in secret_ref / Vault.
    -- email:    { "from": "...", "host": "...", "port": 587, "use_tls": true }
    -- msteams:  { "webhook_url_ref": "vault:...", "theme_color_default": "0078D4" }
    -- webhook:  { "base_url": "https://svc/internal/notify", "method": "POST",
    --             "headers": {"X-Service":"notif"}, "timeout_ms": 5000,
    --             "auth_ref": "vault:..." }
    config          JSONB NOT NULL DEFAULT '{}'::jsonb,
    secret_ref      TEXT,                         -- pointer to Vault / K8s secret
    is_default      BOOLEAN NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (channel_id, code)
);

CREATE UNIQUE INDEX uq_channel_endpoints_default
    ON channel_endpoints(channel_id)
    WHERE is_default AND is_active;

-- ---------------------------------------------------------------------------
-- Recipients & groups
-- ---------------------------------------------------------------------------
CREATE TABLE recipient_groups (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,         -- de-oncall, core-alerts
    display_name    TEXT NOT NULL,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recipients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    -- address kind depends on channel: email addr, teams user/channel id, etc.
    channel_type    TEXT NOT NULL
                        CHECK (channel_type IN ('email','msteams','webhook','slack','sms')),
    address         CITEXT NOT NULL,              -- user@x.com | teams://channel/... | https://...
    display_name    TEXT,
    metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (channel_type, address)
);

CREATE TABLE recipient_group_members (
    group_id        UUID NOT NULL REFERENCES recipient_groups(id) ON DELETE CASCADE,
    recipient_id    UUID NOT NULL REFERENCES recipients(id) ON DELETE CASCADE,
    PRIMARY KEY (group_id, recipient_id)
);

-- ---------------------------------------------------------------------------
-- Templates (versioned, multi-channel body)
-- ---------------------------------------------------------------------------
CREATE TABLE templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,         -- airflow.dag.failed
    display_name    TEXT NOT NULL,
    description     TEXT,
    source_system_id UUID REFERENCES source_systems(id) ON DELETE SET NULL,
    -- JSON Schema (draft-07+) describing required payload.variables
    variables_schema JSONB NOT NULL DEFAULT '{}'::jsonb,
    status          TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','active','archived')),
    current_version INT NOT NULL DEFAULT 0,
    created_by      TEXT,
    updated_by      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE template_versions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_id     UUID NOT NULL REFERENCES templates(id) ON DELETE CASCADE,
    version         INT NOT NULL,
    channel_type    TEXT NOT NULL
                        CHECK (channel_type IN ('email','msteams','webhook','slack','sms')),
    -- email: subject + html_body + text_body
    -- msteams: adaptive_card JSON or message_card JSON (Mustache/Jinja placeholders)
    -- webhook: request_body template JSON
    subject         TEXT,
    body            TEXT NOT NULL,
    body_format     TEXT NOT NULL DEFAULT 'text'
                        CHECK (body_format IN ('text','html','markdown','adaptive_card','json')),
    locale          TEXT NOT NULL DEFAULT 'en',
    changelog       TEXT,
    created_by      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (template_id, version, channel_type, locale)
);

CREATE INDEX idx_template_versions_lookup
    ON template_versions(template_id, channel_type, locale, version DESC);

-- ---------------------------------------------------------------------------
-- Routing rules: which template + channels for an event from a source
-- ---------------------------------------------------------------------------
CREATE TABLE routing_rules (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    source_system_id UUID NOT NULL REFERENCES source_systems(id) ON DELETE CASCADE,
    -- matchers (all ANDed). Empty event_type = match all for that source.
    event_type      TEXT,                         -- dag.failed, pipeline.success, …
    severity_min    TEXT CHECK (severity_min IN ('info','warning','error','critical')),
    -- optional JSONPath / CEL-like filter on payload, e.g. payload.env == "prod"
    match_expr      TEXT,
    template_id     UUID NOT NULL REFERENCES templates(id),
    priority        INT NOT NULL DEFAULT 100,     -- lower = higher priority
    status          TEXT NOT NULL DEFAULT 'active'
                        CHECK (status IN ('active','disabled')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_routing_rules_source_event
    ON routing_rules(source_system_id, event_type, status, priority);

CREATE TABLE routing_rule_channels (
    rule_id             UUID NOT NULL REFERENCES routing_rules(id) ON DELETE CASCADE,
    channel_id          UUID NOT NULL REFERENCES channels(id),
    channel_endpoint_id UUID REFERENCES channel_endpoints(id),
    recipient_group_id  UUID REFERENCES recipient_groups(id),
    -- override recipients from request payload if true
    allow_payload_recipients BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (rule_id, channel_id)
);

-- ---------------------------------------------------------------------------
-- Inbound notify requests (API audit) + deliveries
-- ---------------------------------------------------------------------------
CREATE TABLE notification_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key TEXT,                         -- client-provided for dedupe
    source_system_id UUID NOT NULL REFERENCES source_systems(id),
    api_client_id   UUID REFERENCES api_clients(id),
    event_type      TEXT NOT NULL,
    severity        TEXT NOT NULL DEFAULT 'info'
                        CHECK (severity IN ('info','warning','error','critical')),
    -- original body from caller
    payload         JSONB NOT NULL,
    -- optional explicit overrides
    template_code   TEXT,
    channel_codes   TEXT[],
    correlation_id  TEXT,                         -- dag_run_id, trace_id, …
    status          TEXT NOT NULL DEFAULT 'accepted'
                        CHECK (status IN ('accepted','rejected','queued')),
    reject_reason   TEXT,
    kafka_topic     TEXT,
    kafka_partition INT,
    kafka_offset    BIGINT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_notification_requests_idem
    ON notification_requests(source_system_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_notification_requests_created
    ON notification_requests(created_at DESC);
CREATE INDEX idx_notification_requests_source_event
    ON notification_requests(source_system_id, event_type, created_at DESC);
CREATE INDEX idx_notification_requests_correlation
    ON notification_requests(correlation_id)
    WHERE correlation_id IS NOT NULL;

CREATE TABLE notification_deliveries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES notification_requests(id) ON DELETE CASCADE,
    routing_rule_id UUID REFERENCES routing_rules(id),
    template_id     UUID REFERENCES templates(id),
    template_version INT,
    channel_id      UUID NOT NULL REFERENCES channels(id),
    channel_endpoint_id UUID REFERENCES channel_endpoints(id),
    recipient_id    UUID REFERENCES recipients(id),
    -- denormalized for search when recipient row not used
    recipient_address TEXT,
    rendered_subject TEXT,
    rendered_body   TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','sending','sent','failed','skipped','dead')),
    attempt_count   INT NOT NULL DEFAULT 0,
    max_attempts    INT NOT NULL DEFAULT 5,
    next_retry_at   TIMESTAMPTZ,
    provider_message_id TEXT,                     -- SMTP message-id / Teams activity id
    error_code      TEXT,
    error_message   TEXT,
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_deliveries_request ON notification_deliveries(request_id);
CREATE INDEX idx_deliveries_status_retry
    ON notification_deliveries(status, next_retry_at)
    WHERE status IN ('pending','failed');
CREATE INDEX idx_deliveries_created ON notification_deliveries(created_at DESC);

CREATE TABLE delivery_attempts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id     UUID NOT NULL REFERENCES notification_deliveries(id) ON DELETE CASCADE,
    attempt_no      INT NOT NULL,
    status          TEXT NOT NULL CHECK (status IN ('sent','failed')),
    http_status     INT,
    response_body   TEXT,
    error_message   TEXT,
    duration_ms     INT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (delivery_id, attempt_no)
);

-- ---------------------------------------------------------------------------
-- Optional: outbound calls to other internal services (not just Teams/Email)
-- ---------------------------------------------------------------------------
CREATE TABLE service_integrations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,         -- pagerduty-bridge, slack-gateway, oms-alert
    display_name    TEXT NOT NULL,
    channel_endpoint_id UUID NOT NULL REFERENCES channel_endpoints(id),
    -- map notification fields → downstream service contract
    request_mapping JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_mapping JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_source_systems_updated BEFORE UPDATE ON source_systems
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_channels_updated BEFORE UPDATE ON channels
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_channel_endpoints_updated BEFORE UPDATE ON channel_endpoints
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_templates_updated BEFORE UPDATE ON templates
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_routing_rules_updated BEFORE UPDATE ON routing_rules
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_deliveries_updated BEFORE UPDATE ON notification_deliveries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_recipient_groups_updated BEFORE UPDATE ON recipient_groups
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_service_integrations_updated BEFORE UPDATE ON service_integrations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Notification Platform — PostgreSQL schema
-- Caller contract: only notification_id (UUID) + optional payload.
-- Template, channels, recipients, severity — managed entirely on the portal.

CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "citext";

-- channel_type:     email | msteams | webhook | slack | sms
-- severity:         info | warning | error | critical
-- request_status:   accepted | rejected | queued
-- delivery_status:  pending | sending | sent | failed | skipped | dead
-- entity_status:    draft | active | archived

-- ---------------------------------------------------------------------------
-- Source systems (who may call /notification/notify with an API key)
-- ---------------------------------------------------------------------------
CREATE TABLE source_systems (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,
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
    api_key_hash    TEXT NOT NULL,
    api_key_prefix  TEXT NOT NULL,
    scopes          TEXT[] NOT NULL DEFAULT ARRAY['notify']::TEXT[],
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    expires_at      TIMESTAMPTZ,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (source_system_id, client_name)
);

CREATE INDEX idx_api_clients_prefix ON api_clients(api_key_prefix);

-- ---------------------------------------------------------------------------
-- Channels & endpoints
-- ---------------------------------------------------------------------------
CREATE TABLE channels (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    channel_type    TEXT NOT NULL
                        CHECK (channel_type IN ('email','msteams','webhook','slack','sms')),
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE channel_endpoints (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    code            TEXT NOT NULL,
    display_name    TEXT NOT NULL,
    config          JSONB NOT NULL DEFAULT '{}'::jsonb,
    secret_ref      TEXT,
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
    code            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    description     TEXT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE recipients (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_type    TEXT NOT NULL
                        CHECK (channel_type IN ('email','msteams','webhook','slack','sms')),
    address         CITEXT NOT NULL,
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
-- Templates (versioned, multi-channel body) — managed on portal
-- ---------------------------------------------------------------------------
CREATE TABLE templates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    description     TEXT,
    -- JSON Schema for payload variables callers may pass
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
-- Notifications — portal-managed units. Callers only pass this UUID.
-- ---------------------------------------------------------------------------
CREATE TABLE notifications (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),  -- << service passes this
    code            TEXT NOT NULL UNIQUE,         -- human slug on portal, e.g. airflow-dag-failed
    display_name    TEXT NOT NULL,
    description     TEXT,
    template_id     UUID NOT NULL REFERENCES templates(id),
    severity        TEXT NOT NULL DEFAULT 'info'
                        CHECK (severity IN ('info','warning','error','critical')),
    -- optional override of template.variables_schema for this notification
    variables_schema JSONB,
    status          TEXT NOT NULL DEFAULT 'draft'
                        CHECK (status IN ('draft','active','archived')),
    -- if empty ACL, any authenticated source may fire; else whitelist only
    created_by      TEXT,
    updated_by      TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_notifications_status ON notifications(status);

-- Which channel endpoints + recipient groups this UUID fans out to
CREATE TABLE notification_targets (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id     UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    channel_id          UUID NOT NULL REFERENCES channels(id),
    channel_endpoint_id UUID REFERENCES channel_endpoints(id),
    recipient_group_id  UUID REFERENCES recipient_groups(id),
    -- for webhook → other services
    service_integration_id UUID,
    sort_order          INT NOT NULL DEFAULT 0,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (notification_id, channel_id, channel_endpoint_id, recipient_group_id)
);

-- Optional: restrict which source systems may invoke this UUID
CREATE TABLE notification_allowed_sources (
    notification_id  UUID NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,
    source_system_id UUID NOT NULL REFERENCES source_systems(id) ON DELETE CASCADE,
    PRIMARY KEY (notification_id, source_system_id)
);

-- ---------------------------------------------------------------------------
-- Service integrations (call other notify services via webhook channel)
-- ---------------------------------------------------------------------------
CREATE TABLE service_integrations (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code            TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    channel_endpoint_id UUID NOT NULL REFERENCES channel_endpoints(id),
    request_mapping JSONB NOT NULL DEFAULT '{}'::jsonb,
    response_mapping JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE notification_targets
    ADD CONSTRAINT fk_notification_targets_integration
    FOREIGN KEY (service_integration_id) REFERENCES service_integrations(id);

-- ---------------------------------------------------------------------------
-- Inbound notify requests + deliveries
-- ---------------------------------------------------------------------------
CREATE TABLE notification_requests (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    notification_id UUID NOT NULL REFERENCES notifications(id),
    source_system_id UUID NOT NULL REFERENCES source_systems(id),
    api_client_id   UUID REFERENCES api_clients(id),
    -- only dynamic data from caller; all routing comes from notification_id
    payload         JSONB NOT NULL DEFAULT '{}'::jsonb,
    idempotency_key TEXT,
    correlation_id  TEXT,
    status          TEXT NOT NULL DEFAULT 'accepted'
                        CHECK (status IN ('accepted','rejected','queued')),
    reject_reason   TEXT,
    kafka_topic     TEXT,
    kafka_partition INT,
    kafka_offset    BIGINT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX uq_notification_requests_idem
    ON notification_requests(notification_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

CREATE INDEX idx_notification_requests_created
    ON notification_requests(created_at DESC);
CREATE INDEX idx_notification_requests_notif
    ON notification_requests(notification_id, created_at DESC);
CREATE INDEX idx_notification_requests_correlation
    ON notification_requests(correlation_id)
    WHERE correlation_id IS NOT NULL;

CREATE TABLE notification_deliveries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id      UUID NOT NULL REFERENCES notification_requests(id) ON DELETE CASCADE,
    notification_id UUID NOT NULL REFERENCES notifications(id),
    target_id       UUID REFERENCES notification_targets(id),
    template_id     UUID REFERENCES templates(id),
    template_version INT,
    channel_id      UUID NOT NULL REFERENCES channels(id),
    channel_endpoint_id UUID REFERENCES channel_endpoints(id),
    recipient_id    UUID REFERENCES recipients(id),
    recipient_address TEXT,
    rendered_subject TEXT,
    rendered_body   TEXT,
    status          TEXT NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','sending','sent','failed','skipped','dead')),
    attempt_count   INT NOT NULL DEFAULT 0,
    max_attempts    INT NOT NULL DEFAULT 5,
    next_retry_at   TIMESTAMPTZ,
    provider_message_id TEXT,
    error_code      TEXT,
    error_message   TEXT,
    sent_at         TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_deliveries_request ON notification_deliveries(request_id);
CREATE INDEX idx_deliveries_notification ON notification_deliveries(notification_id, created_at DESC);
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
CREATE TRIGGER trg_notifications_updated BEFORE UPDATE ON notifications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_deliveries_updated BEFORE UPDATE ON notification_deliveries
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_recipient_groups_updated BEFORE UPDATE ON recipient_groups
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER trg_service_integrations_updated BEFORE UPDATE ON service_integrations
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

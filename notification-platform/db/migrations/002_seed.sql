-- Seed: portal-managed notifications; callers only need the UUID.

INSERT INTO source_systems (code, display_name, description, owner_team) VALUES
    ('airflow', 'Apache Airflow', 'DAG & task lifecycle events', 'data-platform'),
    ('etl', 'ETL Pipelines', 'Batch ETL job notifications', 'data-engineering'),
    ('de', 'DE Services', 'Data Engineering microservices', 'data-engineering'),
    ('core', 'Core Platform', 'Core business services', 'platform');

INSERT INTO channels (code, display_name, channel_type, description) VALUES
    ('email', 'Email', 'email', 'SMTP / SES outbound mail'),
    ('msteams', 'Microsoft Teams', 'msteams', 'Incoming webhook / Adaptive Cards'),
    ('webhook', 'HTTP Service', 'webhook', 'Call other internal/external notify services');

INSERT INTO channel_endpoints (channel_id, code, display_name, config, is_default)
SELECT c.id, v.code, v.display_name, v.config::jsonb, v.is_default
FROM channels c
JOIN (VALUES
    ('email', 'smtp-primary', 'Primary SMTP',
     '{"from":"noreply@company.com","host":"smtp.company.com","port":587,"use_tls":true}', TRUE),
    ('msteams', 'teams-de-alerts', 'DE Alerts channel',
     '{"theme_color_default":"0078D4"}', TRUE),
    ('webhook', 'svc-pager-bridge', 'Pager bridge service',
     '{"base_url":"http://pager-bridge.internal/v1/alert","method":"POST","timeout_ms":5000}', TRUE)
) AS v(channel_code, code, display_name, config, is_default)
  ON c.code = v.channel_code;

INSERT INTO recipient_groups (code, display_name, description) VALUES
    ('de-oncall', 'DE On-call', 'Primary DE on-call rotation'),
    ('core-alerts', 'Core Alerts', 'Core platform alert recipients');

INSERT INTO recipients (channel_type, address, display_name) VALUES
    ('email', 'de-oncall@company.com', 'DE Oncall Mail'),
    ('email', 'platform@company.com', 'Platform Mail'),
    ('msteams', 'teams://channel/de-alerts', 'DE Alerts Teams');

INSERT INTO recipient_group_members (group_id, recipient_id)
SELECT g.id, r.id
FROM recipient_groups g
CROSS JOIN recipients r
WHERE (g.code = 'de-oncall' AND r.address IN ('de-oncall@company.com', 'teams://channel/de-alerts'))
   OR (g.code = 'core-alerts' AND r.address IN ('platform@company.com'));

INSERT INTO templates (id, code, display_name, description, variables_schema, status, current_version, created_by)
VALUES (
    'a1000000-0000-4000-8000-000000000001',
    'airflow.dag.failed',
    'Airflow DAG Failed',
    'Body for DAG failure alerts',
    '{
      "type":"object",
      "required":["dag_id","run_id","error"],
      "properties":{
        "dag_id":{"type":"string"},
        "run_id":{"type":"string"},
        "logical_date":{"type":"string"},
        "error":{"type":"string"},
        "log_url":{"type":"string"},
        "env":{"type":"string"}
      }
    }'::jsonb,
    'active',
    1,
    'seed'
);

INSERT INTO template_versions (template_id, version, channel_type, subject, body, body_format, created_by)
VALUES
(
    'a1000000-0000-4000-8000-000000000001', 1, 'email',
    '[{{env}}] DAG failed: {{dag_id}}',
    '<h2>DAG failed</h2><p><b>{{dag_id}}</b> / {{run_id}}</p><p>{{error}}</p><p><a href="{{log_url}}">View logs</a></p>',
    'html', 'seed'
),
(
    'a1000000-0000-4000-8000-000000000001', 1, 'msteams',
    NULL,
    '{"type":"AdaptiveCard","body":[{"type":"TextBlock","size":"Large","weight":"Bolder","text":"DAG failed: {{dag_id}}","color":"Attention"}]}',
    'adaptive_card', 'seed'
);

-- Fixed UUID so services can hardcode / inject from config
INSERT INTO notifications (id, code, display_name, description, template_id, severity, status, created_by)
VALUES (
    'n1000000-0000-4000-8000-000000000001',
    'airflow-dag-failed',
    'Airflow DAG Failed',
    'Portal config: email + Teams → de-oncall. Services only pass this UUID.',
    'a1000000-0000-4000-8000-000000000001',
    'error',
    'active',
    'seed'
);

INSERT INTO notification_allowed_sources (notification_id, source_system_id)
SELECT 'n1000000-0000-4000-8000-000000000001', s.id
FROM source_systems s WHERE s.code = 'airflow';

INSERT INTO notification_targets (notification_id, channel_id, channel_endpoint_id, recipient_group_id, sort_order)
SELECT
    'n1000000-0000-4000-8000-000000000001',
    ch.id,
    ce.id,
    g.id,
    CASE ch.code WHEN 'email' THEN 1 WHEN 'msteams' THEN 2 ELSE 3 END
FROM channels ch
JOIN channel_endpoints ce ON ce.channel_id = ch.id AND ce.is_default
JOIN recipient_groups g ON g.code = 'de-oncall'
WHERE ch.code IN ('email', 'msteams');

INSERT INTO service_integrations (code, display_name, channel_endpoint_id, request_mapping, is_active)
SELECT
    'pagerduty-bridge',
    'PagerDuty Bridge',
    ce.id,
    '{"summary":"{{payload.service}} alert","severity":"{{severity}}"}'::jsonb,
    TRUE
FROM channel_endpoints ce WHERE ce.code = 'svc-pager-bridge';

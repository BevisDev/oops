-- Seed data for local / staging demo

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
     '{"theme_color_default":"0078D4","mention_oncall":true}', TRUE),
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

-- Template: Airflow DAG failed
INSERT INTO templates (code, display_name, description, source_system_id, variables_schema, status, current_version, created_by)
SELECT
    'airflow.dag.failed',
    'Airflow DAG Failed',
    'Sent when a DAG run ends in failed state',
    s.id,
    '{
      "type":"object",
      "required":["dag_id","run_id","logical_date","error"],
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
FROM source_systems s WHERE s.code = 'airflow';

INSERT INTO template_versions (template_id, version, channel_type, subject, body, body_format, created_by)
SELECT t.id, 1, 'email',
       '[{{env}}] DAG failed: {{dag_id}}',
       '<h2>DAG failed</h2><p><b>{{dag_id}}</b> / {{run_id}}</p><p>{{error}}</p><p><a href="{{log_url}}">View logs</a></p>',
       'html', 'seed'
FROM templates t WHERE t.code = 'airflow.dag.failed';

INSERT INTO template_versions (template_id, version, channel_type, subject, body, body_format, created_by)
SELECT t.id, 1, 'msteams',
       NULL,
       '{
         "type":"AdaptiveCard",
         "body":[
           {"type":"TextBlock","size":"Large","weight":"Bolder","text":"DAG failed: {{dag_id}}","color":"Attention"},
           {"type":"FactSet","facts":[
             {"title":"Run","value":"{{run_id}}"},
             {"title":"Date","value":"{{logical_date}}"},
             {"title":"Env","value":"{{env}}"}
           ]},
           {"type":"TextBlock","text":"{{error}}","wrap":true}
         ],
         "actions":[{"type":"Action.OpenUrl","title":"Open logs","url":"{{log_url}}"}]
       }',
       'adaptive_card', 'seed'
FROM templates t WHERE t.code = 'airflow.dag.failed';

INSERT INTO routing_rules (code, display_name, source_system_id, event_type, severity_min, template_id, priority, status)
SELECT
    'airflow-dag-failed-prod',
    'Airflow DAG failed → DE oncall',
    s.id,
    'dag.failed',
    'error',
    t.id,
    10,
    'active'
FROM source_systems s
JOIN templates t ON t.code = 'airflow.dag.failed'
WHERE s.code = 'airflow';

INSERT INTO routing_rule_channels (rule_id, channel_id, channel_endpoint_id, recipient_group_id)
SELECT rr.id, ch.id, ce.id, g.id
FROM routing_rules rr
JOIN channels ch ON ch.code IN ('email', 'msteams')
JOIN channel_endpoints ce ON ce.channel_id = ch.id AND ce.is_default
JOIN recipient_groups g ON g.code = 'de-oncall'
WHERE rr.code = 'airflow-dag-failed-prod';

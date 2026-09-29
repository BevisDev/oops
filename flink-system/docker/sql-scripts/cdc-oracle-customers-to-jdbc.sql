-- Example: realtime sync Oracle CDC (via Debezium -> Kafka) into PostgreSQL.
-- Topic naming follows schemas-gitops / kafka-connect: cdc.oracle.<SCHEMA>.<TABLE>
--
-- Before enabling the job:
-- 1. Replace bootstrap servers, JDBC URL, credentials (prefer env / secrets).
-- 2. Align column list with the Debezium value schema for CUSTOMERS.
-- 3. Ensure the sink table exists and primary key matches.

SET 'table.exec.sink.upsert-materialize' = 'NONE';

CREATE TABLE customers_cdc (
  ID DECIMAL(38, 0),
  NAME STRING,
  EMAIL STRING,
  UPDATED_AT TIMESTAMP(3),
  PRIMARY KEY (ID) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'cdc.oracle.CORE.CUSTOMERS',
  'properties.bootstrap.servers' = 'kafka-cluster-kafka-bootstrap.kafka.svc:9093',
  'properties.group.id' = 'flink-sync-customers',
  'scan.startup.mode' = 'earliest-offset',
  'format' = 'debezium-json',
  'debezium-json.schema-include' = 'false'
);

CREATE TABLE customers_sink (
  id BIGINT,
  name STRING,
  email STRING,
  updated_at TIMESTAMP(3),
  PRIMARY KEY (id) NOT ENFORCED
) WITH (
  'connector' = 'jdbc',
  'url' = 'jdbc:postgresql://postgres-rw.postgres.svc:5432/dwh',
  'table-name' = 'raw.customers',
  'username' = '${POSTGRES_USER}',
  'password' = '${POSTGRES_PASSWORD}',
  'sink.buffer-flush.max-rows' = '500',
  'sink.buffer-flush.interval' = '2s'
);

INSERT INTO customers_sink
SELECT
  CAST(ID AS BIGINT) AS id,
  NAME AS name,
  EMAIL AS email,
  UPDATED_AT AS updated_at
FROM customers_cdc;

# Flink Cluster (realtime source sync)

Helm chart wrapping Flink Kubernetes Operator CRs:

| Resource | Purpose |
| --- | --- |
| `FlinkDeployment` (session) | Long-running JM/TM pool for multiple sync jobs |
| `FlinkDeployment` (application) | Isolated one-job clusters (recommended for prod sync) |
| `FlinkSessionJob` | Job submitted onto the session cluster |
| `ConfigMap` | SQL scripts mounted into application jobs |

## Prerequisites

1. Install **cert-manager** (webhook certs).
2. Install **flink-operator** chart (`../flink-operator`).
3. Build & push the custom Flink image (`../../docker/Dockerfile`).

## Install

```sh
kubectl create namespace flink

helm upgrade --install flink-cluster . \
  -n flink \
  -f values.yaml \
  -f values-prod.yaml
```

## Realtime sync flow

```
Oracle / Postgres / MySQL
        │  Debezium (kafka-connect)
        ▼
   Kafka topics  cdc.<source>....
        │  Flink SQL (Kafka source → JDBC / Iceberg / ...)
        ▼
   Target warehouse / OLTP
```

Enable a sync job in `values.yaml`:

```yaml
sqlConfigMaps:
  - name: flink-sql-cdc-customers
    enabled: true
    files:
      cdc-oracle-customers-to-jdbc.sql: |
        -- paste / adapt docker/sql-scripts/cdc-oracle-customers-to-jdbc.sql

deployments:
  - name: sync-cdc-customers
    enabled: true
    sqlConfigMap: flink-sql-cdc-customers
    args:
      - /opt/flink/usrlib/sql-scripts/cdc-oracle-customers-to-jdbc.sql
    parallelism: 2
    upgradeMode: last-state
```

## Docs

- [Flink Kubernetes Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/)
- [Flink SQL Kafka connector](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/kafka/)
- [Flink SQL JDBC connector](https://nightlies.apache.org/flink/flink-docs-release-1.20/docs/connectors/table/jdbc/)

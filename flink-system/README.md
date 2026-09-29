# Apache Flink on Kubernetes

Realtime stream processing for **source sync** (CDC → Kafka → Flink → sink).

## Architecture

```
┌─────────────┐   Debezium    ┌─────────┐   Flink SQL    ┌──────────────┐
│ Oracle/PG/… │ ────────────► │  Kafka  │ ─────────────► │ JDBC / Iceberg│
└─────────────┘  (Connect)    └─────────┘  (this stack)  └──────────────┘
```

This folder follows the same pattern as `kafka-system` / `postgres`:

1. **Operator** – Flink Kubernetes Operator manages `FlinkDeployment` / `FlinkSessionJob`
2. **Cluster chart** – GitOps-friendly values for session cluster + sync jobs
3. **Custom image** – Flink 1.20.2 + Kafka/JDBC connectors + SQL runner

## Quick install

```sh
# 1) Operator
kubectl create namespace flink-operator
helm upgrade --install flink-operator ./helm/flink-operator \
  -n flink-operator -f ./helm/flink-operator/values-prod.yaml

# 2) Image
docker build -t dockerhub.company.com.vn/bevisdev/flink:1.20.2-sync ./docker
docker push dockerhub.company.com.vn/bevisdev/flink:1.20.2-sync

# 3) Session cluster (+ optional sync jobs in values)
kubectl create namespace flink
helm upgrade --install flink-cluster ./helm/flink-cluster \
  -n flink -f ./helm/flink-cluster/values-prod.yaml
```

## Docs

- [Official](https://flink.apache.org/)
- [Install K8s Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/docs/try-flink-kubernetes-operator/quick-start/)
- [Helm charts README](./helm/README.md)

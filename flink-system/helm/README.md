# Flink Helm

We use the official **Flink Kubernetes Operator** chart for the controller and a thin
**flink-cluster** chart for `FlinkDeployment` / `FlinkSessionJob` resources used in
realtime source sync (Kafka CDC → sink).

## Layout

| Path | Role |
| --- | --- |
| `flink-operator/` | Operator 1.16.0 (CRDs + controller + webhook) |
| `flink-cluster/` | Session / application Flink jobs |
| `../docker/` | Custom Flink image (SQL runner + Kafka/JDBC connectors) |

## Getting started

### 1. Prerequisites

```sh
# cert-manager must be installed (webhook certificates)
kubectl get crd certificates.cert-manager.io
```

### 2. Pull / refresh operator chart (optional)

```sh
curl -fsSL -o flink-kubernetes-operator-1.16.0.tgz \
  https://archive.apache.org/dist/flink/flink-kubernetes-operator-1.16.0/flink-kubernetes-operator-1.16.0-helm.tgz
```

Chart sources are already vendored under `flink-operator/`.

### 3. Install operator

```sh
kubectl create namespace flink-operator

helm upgrade --install flink-operator ./flink-operator \
  -n flink-operator \
  -f flink-operator/values.yaml \
  -f flink-operator/values-prod.yaml
```

### 4. Build Flink sync image

```sh
cd ../docker
docker build -t dockerhub.company.com.vn/bevisdev/flink:1.20.2-sync .
docker push dockerhub.company.com.vn/bevisdev/flink:1.20.2-sync
```

### 5. Deploy session cluster / sync jobs

```sh
kubectl create namespace flink

helm upgrade --install flink-cluster ./flink-cluster \
  -n flink \
  -f flink-cluster/values.yaml \
  -f flink-cluster/values-prod.yaml
```

### Images

```sh
docker pull apache/flink-kubernetes-operator:1.16.0
docker pull flink:1.20.2-java17
```

## Document

- [Official Flink](https://flink.apache.org/)
- [Install K8s Operator](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-stable/docs/try-flink-kubernetes-operator/quick-start/)
- [Operator Helm values](https://nightlies.apache.org/flink/flink-kubernetes-operator-docs-release-1.16/docs/deployment/helm/installation/)

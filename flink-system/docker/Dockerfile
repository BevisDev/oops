# Custom Flink image for realtime CDC / Kafka source sync on Kubernetes.
# Includes SQL runner + Kafka / JDBC connectors used by FlinkDeployment jobs.
#
# Build:
#   docker build -t dockerhub.company.com.vn/bevisdev/flink:1.20.2-sync -f Dockerfile .
#
# Args can override connector versions when Flink is bumped.

ARG FLINK_VERSION=1.20.2
ARG FLINK_BASE_IMAGE=flink:${FLINK_VERSION}-java17
ARG KAFKA_CONNECTOR_VERSION=3.4.0-1.20
ARG JDBC_CONNECTOR_VERSION=3.3.0-1.20
ARG POSTGRES_JDBC_VERSION=42.7.7
ARG MAVEN_REPO=https://repo1.maven.org/maven2

# ---------- build sql-runner ----------
FROM maven:3.9.9-eclipse-temurin-17 AS sql-runner-build
WORKDIR /build
COPY sql-runner/pom.xml .
COPY sql-runner/src ./src
RUN mvn -q -DskipTests package \
 && cp target/flink-sql-runner-*.jar /build/sql-runner.jar

# ---------- runtime image ----------
FROM ${FLINK_BASE_IMAGE}

ARG FLINK_VERSION
ARG KAFKA_CONNECTOR_VERSION
ARG JDBC_CONNECTOR_VERSION
ARG POSTGRES_JDBC_VERSION
ARG MAVEN_REPO

LABEL maintainer="dev.binhtt@gmail.com"
LABEL org.opencontainers.image.title="flink-sync"
LABEL org.opencontainers.image.description="Apache Flink with Kafka/JDBC connectors for realtime source sync"

USER root

RUN mkdir -p /opt/flink/usrlib /opt/flink/usrlib/sql-scripts /opt/flink/plugins/metrics-prometheus \
 && curl -fsSL -o /opt/flink/lib/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar \
      ${MAVEN_REPO}/org/apache/flink/flink-sql-connector-kafka/${KAFKA_CONNECTOR_VERSION}/flink-sql-connector-kafka-${KAFKA_CONNECTOR_VERSION}.jar \
 && curl -fsSL -o /opt/flink/lib/flink-connector-jdbc-${JDBC_CONNECTOR_VERSION}.jar \
      ${MAVEN_REPO}/org/apache/flink/flink-connector-jdbc/${JDBC_CONNECTOR_VERSION}/flink-connector-jdbc-${JDBC_CONNECTOR_VERSION}.jar \
 && curl -fsSL -o /opt/flink/lib/postgresql-${POSTGRES_JDBC_VERSION}.jar \
      ${MAVEN_REPO}/org/postgresql/postgresql/${POSTGRES_JDBC_VERSION}/postgresql-${POSTGRES_JDBC_VERSION}.jar \
 && cp /opt/flink/opt/flink-metrics-prometheus-*.jar /opt/flink/plugins/metrics-prometheus/ \
 && chown -R flink:flink /opt/flink/usrlib /opt/flink/lib /opt/flink/plugins/metrics-prometheus

COPY --from=sql-runner-build --chown=flink:flink /build/sql-runner.jar /opt/flink/usrlib/sql-runner.jar
COPY --chown=flink:flink sql-scripts/ /opt/flink/usrlib/sql-scripts/

USER flink

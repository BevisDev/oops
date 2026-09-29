{{/*
Expand the chart name.
*/}}
{{- define "flink-cluster.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "flink-cluster.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "flink-cluster.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/name: {{ include "flink-cluster.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{/*
Service account used by Flink pods (created by flink-operator chart by default).
*/}}
{{- define "flink-cluster.serviceAccountName" -}}
{{- default "flink" .Values.serviceAccountName -}}
{{- end -}}

{{/*
Default Flink image reference.
*/}}
{{- define "flink-cluster.image" -}}
{{- $img := .Values.image | default dict -}}
{{- if $img.repository -}}
{{- printf "%s:%s" $img.repository (default .Chart.AppVersion $img.tag) -}}
{{- else -}}
{{- required "image.repository is required" $img.repository -}}
{{- end -}}
{{- end -}}

{{/*
Resolve flinkVersion enum for FlinkDeployment CR.
*/}}
{{- define "flink-cluster.flinkVersion" -}}
{{- default "v1_20" .Values.flinkVersion -}}
{{- end -}}

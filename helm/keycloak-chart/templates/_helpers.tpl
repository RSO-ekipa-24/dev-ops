{{/*
Create a default fully qualified app name.
We truncate at 63 chars because of K8s name restrictions.
*/}}
{{- define "keycloak-chart.fullname" -}}
{{- $name := default .Chart.Name .Values.keycloak.name -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}


{{/*
Selector labels
*/}}
{{- define "keycloak-chart.selectorLabels" -}}
app.kubernetes.io/name: {{ include "keycloak-chart.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "keycloak-chart.labels" -}}
helm.sh/chart: {{ include "keycloak-chart.chart" . }}
{{ include "keycloak-chart.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Define Name (used by selectorLabels)
*/}}
{{- define "keycloak-chart.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
(Your existing keycloak-chart.fullname definition goes here)
*/}}

{{/*
Chart Name and Version for labels
*/}}
{{- define "keycloak-chart.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | trunc 63 | trimSuffix "-" -}}
{{- end -}}
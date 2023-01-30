{{/*
Expand the name of the chart.
*/}}
{{- define "wireguard.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "wireguard.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a name for the persistent volume claim, used by pvc and pods.
*/}}
{{- define "wireguard.config-storage" -}}
{{- $suffix := default .Values.configStorageSuffix "config" -}}
{{- $appName := include "wireguard.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "wireguard.labels" -}}
helm.sh/chart: {{ include "wireguard.chart" . }}
{{ include "wireguard.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "wireguard.selectorLabels" -}}
app.kubernetes.io/name: {{ include "wireguard.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


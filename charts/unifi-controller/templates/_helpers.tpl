{{/*
Expand the name of the chart.
*/}}
{{- define "unifi-controller.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "unifi-controller.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a name for the web-interface, used by service and ingress.
*/}}
{{- define "unifi-controller.web-interface" -}}
{{- $suffix := default .Values.webInterfaceSuffix "web-interface" -}}
{{- $appName := include "unifi-controller.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create a name for the persistent volume claim, used by pvc and pods.
*/}}
{{- define "unifi-controller.config-storage" -}}
{{- $suffix := default .Values.configStorageSuffix "config" -}}
{{- $appName := include "unifi-controller.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "unifi-controller.labels" -}}
helm.sh/chart: {{ include "unifi-controller.chart" . }}
{{ include "unifi-controller.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "unifi-controller.selectorLabels" -}}
app.kubernetes.io/name: {{ include "unifi-controller.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


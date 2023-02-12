{{/*
Expand the name of the chart.
*/}}
{{- define "pihole.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "pihole.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create chart image name, with version supplied by Chart.AppVersion
*/}}
{{- define "pihole.image" -}}
{{- printf "pihole/pihole:%s" .Chart.AppVersion }}
{{- end }}

{{/*
Create a name for the web-interface, used by service and ingress.
*/}}
{{- define "pihole.web-interface" -}}
{{- $suffix := default .Values.webInterfaceSuffix "web-interface" -}}
{{- $appName := include "pihole.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create a name for the persistent volume claim, used by pvc and pods.
*/}}
{{- define "pihole.config-storage" -}}
{{- $suffix := default .Values.configStorageSuffix "config" -}}
{{- $appName := include "pihole.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Create a name for the secret, used by secret and pod.
*/}}
{{- define "pihole.secret" -}}
{{- $suffix := default .Values.configSecretSuffix "secret" -}}
{{- $appName := include "pihole.name" . -}}
{{- printf "%s-%s" $appName $suffix | trunc 63 | trimSuffix "-" }}
{{- end -}}

{{/*
Common labels
*/}}
{{- define "pihole.labels" -}}
helm.sh/chart: {{ include "pihole.chart" . }}
{{ include "pihole.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "pihole.selectorLabels" -}}
app.kubernetes.io/name: {{ include "pihole.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}


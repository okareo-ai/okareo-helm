{{- define "okareo-redis-ha.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "okareo-redis-ha.fullname" -}}
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

{{- define "okareo-redis-ha.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "okareo-redis-ha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "okareo-redis-ha.selectorLabels" -}}
app.kubernetes.io/name: {{ include "okareo-redis-ha.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "okareo-redis-ha.serviceAccountName" -}}
{{- if .Values.serviceAccount.create -}}
{{- default (printf "%s-sa" (include "okareo-redis-ha.fullname" .)) .Values.serviceAccount.name -}}
{{- else -}}
{{- default "default" .Values.serviceAccount.name -}}
{{- end -}}
{{- end -}}

{{- define "okareo-redis-ha.rwServiceName" -}}
{{- if .Values.service.readWrite.name -}}
{{- .Values.service.readWrite.name -}}
{{- else -}}
{{- printf "%s-rw" (include "okareo-redis-ha.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "okareo-redis-ha.sentinelServiceName" -}}
{{- if .Values.service.sentinel.name -}}
{{- .Values.service.sentinel.name -}}
{{- else -}}
{{- printf "%s-sentinel" (include "okareo-redis-ha.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "okareo-redis-ha.headlessServiceName" -}}
{{- if .Values.service.headless.name -}}
{{- .Values.service.headless.name -}}
{{- else -}}
{{- printf "%s-headless" (include "okareo-redis-ha.fullname" .) -}}
{{- end -}}
{{- end -}}

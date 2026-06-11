{{- define "okareo-standalone.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{- define "okareo-standalone.fullname" -}}
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

{{- define "okareo-standalone.labels" -}}
helm.sh/chart: {{ .Chart.Name }}-{{ .Chart.Version | replace "+" "_" }}
app.kubernetes.io/name: {{ include "okareo-standalone.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end -}}

{{- define "okareo-standalone.selectorLabels" -}}
app.kubernetes.io/name: {{ include "okareo-standalone.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end -}}

{{- define "okareo-standalone.databaseUrl" -}}
{{- if .Values.secrets.databaseUrl -}}
{{- .Values.secrets.databaseUrl -}}
{{- else if .Values.db.enabled -}}
{{- printf "postgresql+psycopg2://%s:%s@%s-db:%v/%s" .Values.secrets.dbUser .Values.secrets.dbPassword (include "okareo-standalone.fullname" .) .Values.db.service.port .Values.secrets.dbName -}}
{{- else -}}
{{- "postgresql+psycopg2://<DB_USER>:<DB_PASSWORD>@<DB_HOST>:5432/<DB_NAME>?sslmode=require" -}}
{{- end -}}
{{- end -}}

{{- define "okareo-standalone.tenantDb" -}}
{{- if .Values.secrets.tenantDb -}}
{{- .Values.secrets.tenantDb -}}
{{- else if .Values.db.enabled -}}
{{- include "okareo-standalone.databaseUrl" . -}}
{{- else -}}
{{- "postgresql+psycopg2://<DB_USER>:<DB_PASSWORD>@<DB_HOST>:5432/<DB_NAME>?sslmode=require" -}}
{{- end -}}
{{- end -}}

{{- define "okareo-standalone.airgapNatsUrl" -}}
{{- if and .Values.nats.external.enabled .Values.nats.external.url -}}
{{- .Values.nats.external.url -}}
{{- else -}}
{{- printf "nats://%s-nats:%v" (include "okareo-standalone.fullname" .) .Values.nats.service.port -}}
{{- end -}}
{{- end -}}

{{- define "okareo-standalone.redisHost" -}}
{{- if .Values.redis.external.host -}}
{{- .Values.redis.external.host -}}
{{- else -}}
{{- printf "%s-redis" (include "okareo-standalone.fullname" .) -}}
{{- end -}}
{{- end -}}

{{- define "okareo-standalone.redisPort" -}}
{{- if .Values.redis.external.port -}}
{{- printf "%v" .Values.redis.external.port -}}
{{- else -}}
{{- printf "%v" .Values.redis.service.port -}}
{{- end -}}
{{- end -}}

{{- define "okareo-standalone.secretName" -}}
{{- if .Values.secrets.existingSecretName -}}
{{- .Values.secrets.existingSecretName -}}
{{- else -}}
{{- printf "%s-secrets" (include "okareo-standalone.fullname" .) -}}
{{- end -}}
{{- end -}}

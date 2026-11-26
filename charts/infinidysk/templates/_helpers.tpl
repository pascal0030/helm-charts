{{/*
Expand the name of the chart.
*/}}
{{- define "infinidysk.name" -}}
{{- include "common.name" . -}}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "infinidysk.fullname" -}}
{{- include "common.fullname" . -}}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "infinidysk.chart" -}}
{{- include "common.chart" . -}}
{{- end }}

{{/*
Common labels
*/}}
{{- define "infinidysk.labels" -}}
{{- include "common.labels" . -}}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "infinidysk.selectorLabels" -}}
{{- include "common.selectorLabels" . -}}
{{- end }}

{{/*
Return the proper infinidysk image name
*/}}
{{- define "infinidysk.image" -}}
{{- include "common.image" (dict "image" .Values.image "global" .Values.global) -}}
{{- end }}

{{/*
Return the proper Docker Image Registry Secret Names
*/}}
{{- define "infinidysk.imagePullSecrets" -}}
{{ include "common.images.renderPullSecrets" (dict "images" (list .Values.image) "context" .) }}
{{- end -}}

{{/*
Turn a setting path such as `mount.dir` into the environment variable infinidysk reads for it.
See https://www.infinidysk.com/v2/reference/environment/#naming
*/}}
{{- define "infinidysk.settingEnvName" -}}
{{- printf "INFINIDYSK__%s" (replace "." "__" . | upper) -}}
{{- end -}}

{{/*
Render a setting value. Lists and objects are passed as the JSON infinidysk expects.
*/}}
{{- define "infinidysk.settingValue" -}}
{{- if or (kindIs "map" .) (kindIs "slice" .) -}}
{{- toJson . -}}
{{- else -}}
{{- . | toString -}}
{{- end -}}
{{- end -}}

{{/*
The settings this chart derives from its own values, merged with config.settings.
Anything set in config.settings wins, so a setting is never defined twice.
*/}}
{{- define "infinidysk.settings" -}}
{{- $derived := dict "mount.fuse" .Values.mount.fuse -}}
{{- if .Values.mount.dir -}}
{{- $_ := set $derived "mount.dir" .Values.mount.dir -}}
{{- end -}}
{{- if .Values.metrics.enabled -}}
{{- $_ := set $derived "metrics.prometheus" true -}}
{{- end -}}
{{- toYaml (merge (deepCopy .Values.config.settings) $derived) -}}
{{- end -}}

{{/*
The INFINIDYSK__… environment variables for the plain (non-secret) settings.
*/}}
{{- define "infinidysk.settingsEnv" -}}
{{- range $path, $value := (include "infinidysk.settings" . | fromYaml) }}
- name: {{ include "infinidysk.settingEnvName" $path }}
  value: {{ include "infinidysk.settingValue" $value | quote }}
{{- end }}
{{- end -}}

{{/*
The contents of the Secret this chart creates, as a map of environment variable name to value.
*/}}
{{- define "infinidysk.secretValues" -}}
{{- $data := dict -}}
{{- with .Values.auth.apiKey }}{{- $_ := set $data "INFINIDYSK__AUTH__API_KEY" . -}}{{- end -}}
{{- with .Values.auth.sessionKey }}{{- $_ := set $data "INFINIDYSK__AUTH__SESSION_KEY" . -}}{{- end -}}
{{- with .Values.auth.sabApiKey }}{{- $_ := set $data "INFINIDYSK__SAB__API_KEY" . -}}{{- end -}}
{{- with .Values.auth.webdavUser }}{{- $_ := set $data "INFINIDYSK__WEBDAV__USER" . -}}{{- end -}}
{{- with .Values.auth.webdavPassword }}{{- $_ := set $data "INFINIDYSK__WEBDAV__PASSWORD" . -}}{{- end -}}
{{- if and .Values.config.database.url (not .Values.config.database.existingSecret) -}}
{{- $_ := set $data "INFINIDYSK_DATABASE_URL" .Values.config.database.url -}}
{{- end -}}
{{- range $path, $value := .Values.config.secretSettings -}}
{{- $_ := set $data (include "infinidysk.settingEnvName" $path) (include "infinidysk.settingValue" $value) -}}
{{- end -}}
{{- toYaml $data -}}
{{- end -}}

{{/*
Whether this chart creates a Secret of its own.
*/}}
{{- define "infinidysk.createSecret" -}}
{{- if and .Values.auth.createSecret (include "infinidysk.secretValues" . | fromYaml) -}}
true
{{- end -}}
{{- end -}}

{{/*
Name of the Secret holding the admin API key, for the ServiceMonitor bearer token.
*/}}
{{- define "infinidysk.apiKeySecretName" -}}
{{- if .Values.metrics.serviceMonitor.bearerTokenSecret.name -}}
{{- .Values.metrics.serviceMonitor.bearerTokenSecret.name -}}
{{- else if and (include "infinidysk.createSecret" .) .Values.auth.apiKey -}}
{{- include "infinidysk.fullname" . -}}
{{- end -}}
{{- end -}}

{{/*
Key in that Secret.
*/}}
{{- define "infinidysk.apiKeySecretKey" -}}
{{- .Values.metrics.serviceMonitor.bearerTokenSecret.key | default "INFINIDYSK__AUTH__API_KEY" -}}
{{- end -}}

{{/*
Validate values of infinidysk - Mount
*/}}
{{- define "infinidysk.validateValues.mount" -}}
{{- if and .Values.mount.hostPath.enabled (eq .Values.mount.hostPath.mountPropagation "Bidirectional") (not .Values.containerSecurityContext.privileged) -}}
infinidysk: mount.hostPath
    Bidirectional mount propagation is only allowed for privileged containers.
    Set containerSecurityContext.privileged=true, or pick another
    mount.hostPath.mountPropagation.
{{- end -}}
{{- end -}}

{{/*
Compile all validations and fail with a single message.
*/}}
{{- define "infinidysk.validateValues" -}}
{{- $messages := list -}}
{{- $messages = append $messages (include "infinidysk.validateValues.mount" .) -}}
{{- $messages = without $messages "" -}}
{{- $message := join "\n" $messages -}}
{{- if $message -}}
{{- printf "\nVALUES VALIDATION:\n%s" $message | fail -}}
{{- end -}}
{{- end -}}

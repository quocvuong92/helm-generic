{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "generic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "generic.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "generic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "generic.labels" -}}
helm.sh/chart: {{ include "generic.chart" . }}
{{ include "generic.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Common annotations
*/}}
{{- define "generic.annotations" -}}
"helm.sh/chart": {{ include "generic.chart" . | quote }}
"meta.helm.sh/release-name": {{ .Release.Name | quote }}
"meta.helm.sh/release-namespace": {{ .Release.Namespace | quote }}
{{- end
}}



{{/*
Selector labels
*/}}
{{- define "generic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Create the name of the service account to use
*/}}
{{- define "generic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "generic.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{- /*
Define the image. This is helpful in case the tag has a sha in it

Should be passed values directly
 */ -}}
{{- define "generic.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if hasPrefix "sha256:" $tag -}}
"{{ .Values.image.repository }}@{{ $tag }}"
{{- else -}}
"{{ .Values.image.repository }}:{{ $tag }}"
{{- end }}
{{- end }}

{{/* thanks to https://github.com/bitnami/charts/blob/master/bitnami/common/templates/_tplvalues.tpl */}}
{{/*
Renders a value that contains template.
Usage:
{{ include "generic.tplvalues.render" ( dict "value" .Values.path.to.the.Value "context" $) }}
*/}}
{{- define "generic.tplvalues.render" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context | trim }}
{{- else }}
{{- tpl (.value | toYaml) .context | trim }}
{{- end }}
{{- end -}}


{{- /*
  Determines the key given a "config" object and an "index"
    Optional key "filePrefix" defaults to "config-file"
    Optional key "fileExt" defaults to ".txt"
  Usage:
    {{ include "generic.config.key" (dict "index" 1 "content" (dict "name" "hi") }}
 */ -}}
{{- define "generic.config.key" -}}
  {{- $filePrefix := default .filePrefix "config-file" }}
  {{- $fileExt := default .fileExt ".txt" }}
  {{- if hasKey .content "name" }}
    {{- print (get .content "name") }}
  {{- else }}
    {{- printf "%s-%d%s" $filePrefix .index $fileExt }}
  {{- end}}
{{- end -}}

{{- /*
  Given a:
    - value: list of maps with mountPath and "content" keys
    - volumeName: optional name of the volume. Defaults to "config-volume"
  Generate:
    - a list of "volumeMount:" configurations that:
      - reference the named `volume`
      - choose a `subPath` based on the naming convention (i.e. either the name in the "content" key or the index)
      - choose a `mountPath` based on the "mountPath" key
  Usage: {{ include "generic.config.volumeMount" (dict "value" .Values.configMount "volumeName" "config-volume" ) }}
 */ -}}
{{- define "generic.config.volumeMount" }}
  {{- $volumeName := .volumeName | default "config-volume" }}
  {{- range $i, $config := .value }}
    {{- if not (and (hasKey $config "mountPath") (hasKey $config "content")) }}
      {{- fail "keys 'mountPath' and 'content' are required for mountConfig entries" }}
    {{- end }}
- name: {{ $volumeName }}
  mountPath: {{ get $config "mountPath" }}
  subPath: {{ base (get $config "mountPath") }}
  {{- end }}
{{- end }}

{{- /*
  Given a:
    - value: a list of maps with "mountPath" and "content" keys (along with recommended "name" key)
    - context: the context for templating to be evaluated within. Usually global
  Generate a:
    - ConfigMap "spec" / "data"
    - map of entries
    - evaluate each "content" key as a template

  Usage: {{ include "generic.config.configmap" (dict "value" .Values.configMount "context" . )}}
*/ -}}
{{- define "generic.config.configmap" -}}
  {{- if or (not (hasKey . "context")) (not (hasKey . "value")) }}
    {{- fail "generic.config requires both a context and a value key" }}
  {{- end }}
  {{- $global := .context }}
  {{- /* TODO: find a way to ensure names are unique...? */ -}}
  {{- range $i, $config := .value }}
    {{- if not (and (hasKey $config "mountPath") (hasKey $config "content")) }}
      {{- fail "keys 'mountPath' and 'content' are required for mountConfig entries" }}
    {{- end }}
  {{- /* name */ -}}
  {{- include "generic.config.key" (dict "index" $i "content" $config ) | nindent 0 }}: |-
    {{- /* contents */ -}}
    {{- $content := get $config "content" }}
    {{- include "generic.tplvalues.render" (dict "value" $content "context" $global ) | nindent 2 }}
  {{- end }}
{{- end }}

{{- /*
  Shared pod labels with checksum annotations for automatic rollover
  Usage: {{ include "generic.podLabels" . | nindent 8 }}
*/ -}}
{{- define "generic.podLabels" -}}
{{- include "generic.selectorLabels" . }}
{{- with .Values.pod.labels }}
{{ toYaml . }}
{{- end }}
{{- if .Values.includeMountLabel }}
{{- if .Values.mountConfig }}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum | trunc 63 }}
{{- end }}
{{- if .Values.mountSecret }}
checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum | trunc 63 }}
{{- end }}
{{- end }}
{{- end -}}

{{- /*
  Shared volume mounts for containers
  Usage: {{ include "generic.volumeMounts" . | nindent 12 }}
*/ -}}
{{- define "generic.volumeMounts" -}}
{{- if .Values.storage.create -}}
- name: storage
  mountPath: {{ .Values.storage.mountPath }}
  {{- with .Values.storage.subPath }}
  subPath: {{ . }}
  {{- end }}
{{- end -}}
{{- with .Values.pod.volumeMounts }}
{{ toYaml . }}
{{- end -}}
{{- with .Values.mountConfig }}
{{ include "generic.config.volumeMount" (dict "value" . "volumeName" "config-volume") }}
{{- end -}}
{{- with .Values.mountSecret }}
{{ include "generic.config.volumeMount" (dict "value" . "volumeName" "secret-volume") }}
{{- end -}}
{{- end -}}

{{- /*
  Shared volumes specification
  Usage: {{ include "generic.volumes" . | nindent 8 }}
*/ -}}
{{- define "generic.volumes" -}}
{{- if .Values.mountConfig -}}
- name: config-volume
  configMap:
    name: {{ include "generic.fullname" . }}-config
    defaultMode: {{ .Values.mountConfigMode }}
{{- end -}}
{{- if .Values.mountSecret -}}
- name: secret-volume
  secret:
    secretName: {{ include "generic.fullname" . }}-secret-mount
    defaultMode: {{ .Values.mountSecretMode }}
{{- end -}}
{{- if .Values.storage.create -}}
- name: storage
  persistentVolumeClaim:
    claimName: {{ default (print (include "generic.fullname" .) "-storage") .Values.storage.name }}
{{- end -}}
{{- with .Values.pod.volumes }}
{{ toYaml . }}
{{- end -}}
{{- end -}}

{{- /*
  Shared environment variables including secretEnv
  Usage: {{ include "generic.env" . | nindent 12 }}
*/ -}}
{{- define "generic.env" -}}
{{- $global := . -}}
{{- with .Values.pod.env }}
{{ toYaml . }}
{{- end -}}
{{- with .Values.secretEnv }}
{{- range $secret := . }}
{{- if or (not (hasKey $secret "name")) (not (hasKey $secret "value")) }}
{{- fail "secretEnv entries require both a 'name' and a 'value' key" }}
{{- end }}
- name: {{ get $secret "name" }}
  valueFrom:
    secretKeyRef:
      name: {{ include "generic.fullname" $global }}-secret-env
      key: {{ get $secret "name" }}
{{- end }}
{{- end -}}
{{- end -}}

{{- /*
  Shared container ports
  Usage: {{ include "generic.containerPorts" . | nindent 12 }}
*/ -}}
{{- define "generic.containerPorts" -}}
{{- range .Values.pod.ports }}
- name: {{ .name }}
  containerPort: {{ .containerPort }}
  protocol: {{ .protocol | default "TCP" }}
{{- end -}}
{{- end -}}

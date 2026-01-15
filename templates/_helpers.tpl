{{/* vim: set filetype=mustache: */}}

{{/*
==============================================================================
MODULE 1: NAMING
==============================================================================
*/}}

{{/*
Expand the name of the chart.
*/}}
{{- define "generic.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
Truncated at 63 chars (DNS naming spec limit).
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
Create chart name and version for chart label.
*/}}
{{- define "generic.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create the name of the service account to use.
*/}}
{{- define "generic.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "generic.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 2: VALIDATION
==============================================================================
*/}}

{{/*
Validate workload type and return it.
Fails if invalid type specified.
*/}}
{{- define "generic.workloadType" -}}
{{- $validTypes := list "deployment" "statefulset" "daemonset" "cronjob" }}
{{- $type := .Values.workload.type | default "deployment" }}
{{- if not (has $type $validTypes) }}
{{- fail (printf "Invalid workload.type '%s'. Must be one of: %s" $type (join ", " $validTypes)) }}
{{- end }}
{{- $type }}
{{- end }}

{{/*
Check if current workload type matches the specified type.
Usage: {{ include "generic.isWorkloadType" (dict "context" . "type" "deployment") }}
*/}}
{{- define "generic.isWorkloadType" -}}
{{- $currentType := include "generic.workloadType" .context }}
{{- if eq $currentType .type }}true{{- end }}
{{- end }}

{{/*
Validate HPA configuration.
HPA is only valid for deployment and statefulset.
*/}}
{{- define "generic.validateHPA" -}}
{{- if .Values.autoscaling.enabled }}
{{- $type := include "generic.workloadType" . }}
{{- if or (eq $type "daemonset") (eq $type "cronjob") }}
{{- fail (printf "autoscaling.enabled cannot be used with workload.type '%s'. HPA only supports deployment and statefulset." $type) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate PDB configuration.
PDB is not valid for cronjob.
*/}}
{{- define "generic.validatePDB" -}}
{{- if .Values.podDisruptionBudget.enabled }}
{{- $type := include "generic.workloadType" . }}
{{- if eq $type "cronjob" }}
{{- fail "podDisruptionBudget.enabled cannot be used with workload.type 'cronjob'." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 3: METADATA (LABELS & ANNOTATIONS)
==============================================================================
*/}}

{{/*
Standard labels for all resources.
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
Selector labels (used in matchLabels).
*/}}
{{- define "generic.selectorLabels" -}}
app.kubernetes.io/name: {{ include "generic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Standard annotations for all resources.
Returns empty string if no global annotations.
*/}}
{{- define "generic.annotations" -}}
{{- with .Values.globalAnnotations -}}
{{- toYaml . }}
{{- end -}}
{{- end }}

{{/*
Render annotations block only if there are annotations.
Usage: {{ include "generic.renderAnnotations" (dict "global" . "local" .Values.service.annotations) }}
*/}}
{{- define "generic.renderAnnotations" -}}
{{- $globalAnnotations := include "generic.annotations" .global -}}
{{- if or $globalAnnotations .local }}
annotations:
  {{- with $globalAnnotations }}
  {{- . | nindent 2 }}
  {{- end }}
  {{- with .local }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
Pod labels including checksums for automatic restart on config change.
*/}}
{{- define "generic.podLabels" -}}
{{ include "generic.selectorLabels" . }}
{{- with .Values.pod.labels }}
{{ toYaml . }}
{{- end }}
{{- if .Values.restartOnConfigChange }}
{{- if .Values.configFiles }}
checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum | trunc 63 }}
{{- end }}
{{- if or .Values.secretFiles .Values.secretEnv }}
checksum/secret: {{ include (print $.Template.BasePath "/secret.yaml") . | sha256sum | trunc 63 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 4: IMAGE
==============================================================================
*/}}

{{/*
Generate full image reference.
Handles both tag and sha256 digest formats.
*/}}
{{- define "generic.image" -}}
{{- $tag := .Values.image.tag | default .Chart.AppVersion }}
{{- if hasPrefix "sha256:" $tag -}}
{{ .Values.image.repository }}@{{ $tag }}
{{- else -}}
{{ .Values.image.repository }}:{{ $tag }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 5: TEMPLATE RENDERING
==============================================================================
*/}}

{{/*
Render a value that contains template.
Usage: {{ include "generic.tplValue" (dict "value" .Values.path.to.value "context" $) }}
*/}}
{{- define "generic.tplValue" -}}
{{- if typeIs "string" .value }}
{{- tpl .value .context | trim }}
{{- else }}
{{- tpl (.value | toYaml) .context | trim }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 6: ENVIRONMENT VARIABLES
==============================================================================
*/}}

{{/*
Generate environment variables for main container.
Combines pod.env and secretEnv references.
*/}}
{{- define "generic.env" -}}
{{- $global := . }}
{{- with .Values.env }}
{{ toYaml . }}
{{- end }}
{{- range $secret := .Values.secretEnv }}
{{- if not (and (hasKey $secret "name") (hasKey $secret "value")) }}
{{- fail "secretEnv entries require both 'name' and 'value' keys" }}
{{- end }}
- name: {{ $secret.name }}
  valueFrom:
    secretKeyRef:
      name: {{ include "generic.fullname" $global }}-secret-env
      key: {{ $secret.name }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 7: CONTAINER PORTS
==============================================================================
*/}}

{{/*
Generate container ports.
*/}}
{{- define "generic.containerPorts" -}}
{{- range .Values.ports }}
- name: {{ .name }}
  containerPort: {{ .containerPort }}
  protocol: {{ .protocol | default "TCP" }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 8: VOLUMES & VOLUME MOUNTS
==============================================================================
*/}}

{{/*
Generate volume mounts for main container.
*/}}
{{- define "generic.volumeMounts" -}}
{{- if .Values.storage.enabled }}
- name: storage
  mountPath: {{ .Values.storage.mountPath }}
  {{- with .Values.storage.subPath }}
  subPath: {{ . }}
  {{- end }}
{{- end }}
{{- range .Values.configFiles }}
{{- if not (and (hasKey . "mountPath") (hasKey . "content")) }}
{{- fail "configFiles entries require 'mountPath' and 'content' keys" }}
{{- end }}
- name: config-volume
  mountPath: {{ .mountPath }}
  subPath: {{ base .mountPath }}
{{- end }}
{{- range .Values.secretFiles }}
{{- if not (and (hasKey . "mountPath") (hasKey . "content")) }}
{{- fail "secretFiles entries require 'mountPath' and 'content' keys" }}
{{- end }}
- name: secret-volume
  mountPath: {{ .mountPath }}
  subPath: {{ base .mountPath }}
{{- end }}
{{- with .Values.pod.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Generate volumes specification.
*/}}
{{- define "generic.volumes" -}}
{{- if .Values.configFiles }}
- name: config-volume
  configMap:
    name: {{ include "generic.fullname" . }}-config
    defaultMode: {{ .Values.configFilesMode }}
{{- end }}
{{- if .Values.secretFiles }}
- name: secret-volume
  secret:
    secretName: {{ include "generic.fullname" . }}-secret
    defaultMode: {{ .Values.secretFilesMode }}
{{- end }}
{{- if .Values.storage.enabled }}
- name: storage
  persistentVolumeClaim:
    claimName: {{ default (printf "%s-storage" (include "generic.fullname" .)) .Values.storage.name }}
{{- end }}
{{- with .Values.pod.volumes }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 9: CONFIG/SECRET DATA
==============================================================================
*/}}

{{/*
Generate ConfigMap data entries from configFiles.
*/}}
{{- define "generic.configData" -}}
{{- $global := .context }}
{{- range .files }}
{{ base .mountPath }}: |
{{- include "generic.tplValue" (dict "value" .content "context" $global) | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate Secret data entries from secretFiles.
*/}}
{{- define "generic.secretData" -}}
{{- $global := .context }}
{{- range .files }}
{{ base .mountPath }}: |
{{- include "generic.tplValue" (dict "value" .content "context" $global) | nindent 2 }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 10: MAIN CONTAINER
==============================================================================
*/}}

{{/*
Generate the main container specification.
*/}}
{{- define "generic.mainContainer" -}}
- name: {{ .Chart.Name }}
  image: {{ include "generic.image" . }}
  imagePullPolicy: {{ .Values.image.pullPolicy }}
  {{- with .Values.command }}
  command:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.args }}
  args:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.securityContext }}
  securityContext:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.envFrom }}
  envFrom:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $env := include "generic.env" . }}
  {{- if $env }}
  env:
    {{- $env | nindent 4 }}
  {{- end }}
  {{- $ports := include "generic.containerPorts" . }}
  {{- if $ports }}
  ports:
    {{- $ports | nindent 4 }}
  {{- end }}
  {{- with .Values.livenessProbe }}
  livenessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.readinessProbe }}
  readinessProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.startupProbe }}
  startupProbe:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.resources }}
  resources:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- $volumeMounts := include "generic.volumeMounts" . }}
  {{- if $volumeMounts }}
  volumeMounts:
    {{- $volumeMounts | nindent 4 }}
  {{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 11: POD SPEC
==============================================================================
*/}}

{{/*
Generate complete pod spec (used by all workload types).
*/}}
{{- define "generic.podSpec" -}}
{{- with .Values.imagePullSecrets }}
imagePullSecrets:
  {{- toYaml . | nindent 2 }}
{{- end -}}
serviceAccountName: {{ include "generic.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- with .Values.pod.terminationGracePeriodSeconds }}
terminationGracePeriodSeconds: {{ . }}
{{- end }}
{{- with .Values.pod.dnsPolicy }}
dnsPolicy: {{ . }}
{{- end }}
{{- with .Values.pod.dnsConfig }}
dnsConfig:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.pod.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.pod.initContainers }}
initContainers:
  {{- toYaml . | nindent 2 }}
{{- end }}
containers:
  {{- include "generic.mainContainer" . | nindent 2 }}
  {{- with .Values.pod.sidecars }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- with .Values.pod.nodeSelector }}
nodeSelector:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.pod.affinity }}
affinity:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.pod.topologySpreadConstraints }}
topologySpreadConstraints:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with .Values.pod.tolerations }}
tolerations:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- $volumes := include "generic.volumes" . }}
{{- if $volumes }}
volumes:
  {{- $volumes | nindent 2 }}
{{- end }}
{{- end }}

{{/*
==============================================================================
MODULE 12: STATEFULSET HELPERS
==============================================================================
*/}}

{{/*
Generate StatefulSet serviceName (defaults to fullname).
*/}}
{{- define "generic.statefulsetServiceName" -}}
{{- default (include "generic.fullname" .) .Values.workload.statefulset.serviceName }}
{{- end }}

{{/*
Generate volumeClaimTemplates for StatefulSet.
*/}}
{{- define "generic.volumeClaimTemplates" -}}
{{- range .Values.workload.statefulset.volumeClaimTemplates }}
- metadata:
    name: {{ .name }}
    {{- with .annotations }}
    annotations:
      {{- toYaml . | nindent 6 }}
    {{- end }}
  spec:
    accessModes:
      {{- toYaml (default (list "ReadWriteOnce") .accessModes) | nindent 6 }}
    {{- with .storageClassName }}
    storageClassName: {{ . }}
    {{- end }}
    resources:
      requests:
        storage: {{ .size | default "10Gi" }}
{{- end }}
{{- end }}

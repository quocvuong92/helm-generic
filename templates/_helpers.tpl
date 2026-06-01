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
Check whether a map has a non-null value for a key.
*/}}
{{- define "generic.hasValue" -}}
{{- if and (hasKey .map .key) (ne (toString (get .map .key)) "<nil>") }}true{{- end }}
{{- end }}

{{- define "generic.validatePodLabels" -}}
{{- with .Values.pod.labels }}
{{- if hasKey . "app.kubernetes.io/name" }}
{{- fail "pod.labels cannot override selector label 'app.kubernetes.io/name'." }}
{{- end }}
{{- if hasKey . "app.kubernetes.io/instance" }}
{{- fail "pod.labels cannot override selector label 'app.kubernetes.io/instance'." }}
{{- end }}
{{- end }}
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
{{- if gt (int .Values.autoscaling.minReplicas) (int .Values.autoscaling.maxReplicas) }}
{{- fail "autoscaling.minReplicas cannot be greater than autoscaling.maxReplicas." }}
{{- end }}
{{- $metrics := default dict .Values.autoscaling.metrics }}
{{- $cpu := default dict (get $metrics "cpu") }}
{{- $memory := default dict (get $metrics "memory") }}
{{- $custom := default list (get $metrics "custom") }}
{{- $hasCPU := and (hasKey $cpu "enabled") (get $cpu "enabled") }}
{{- $hasMemory := and (hasKey $memory "enabled") (get $memory "enabled") }}
{{- $hasCustom := gt (len $custom) 0 }}
{{- if not (or $hasCPU $hasMemory $hasCustom) }}
{{- fail "autoscaling.enabled requires at least one enabled metric: cpu, memory, or autoscaling.metrics.custom." }}
{{- end }}
{{- if and $hasCPU (not (include "generic.hasValue" (dict "map" $cpu "key" "averageUtilization"))) }}
{{- fail "autoscaling.metrics.cpu.averageUtilization is required when autoscaling.metrics.cpu.enabled is true." }}
{{- end }}
{{- if and $hasMemory (not (include "generic.hasValue" (dict "map" $memory "key" "averageUtilization"))) }}
{{- fail "autoscaling.metrics.memory.averageUtilization is required when autoscaling.metrics.memory.enabled is true." }}
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
{{- $pdb := .Values.podDisruptionBudget }}
{{- $hasMin := include "generic.hasValue" (dict "map" $pdb "key" "minAvailable") }}
{{- $hasMax := include "generic.hasValue" (dict "map" $pdb "key" "maxUnavailable") }}
{{- if and $hasMin $hasMax }}
{{- fail "podDisruptionBudget: set only ONE of minAvailable or maxUnavailable, not both." }}
{{- end }}
{{- if not (or $hasMin $hasMax) }}
{{- fail "podDisruptionBudget.enabled requires minAvailable or maxUnavailable." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate storage configuration.
storage.enabled creates a standalone PVC which conflicts with StatefulSet's volumeClaimTemplates.
*/}}
{{- define "generic.validateStorage" -}}
{{- if and .Values.storage.enabled (eq (include "generic.workloadType" .) "statefulset") }}
{{- fail "storage.enabled creates a standalone PVC which is not recommended with StatefulSets. Use workload.statefulset.volumeClaimTemplates instead for per-pod storage." }}
{{- end }}
{{- if and .Values.storage.enabled (eq .Values.storage.volumeMode "Block") (not .Values.storage.devicePath) }}
{{- fail "storage.volumeMode Block requires storage.devicePath." }}
{{- end }}
{{- end }}

{{/*
Validate Ingress dependencies.
*/}}
{{- define "generic.validateIngress" -}}
{{- if .Values.ingress.enabled }}
{{- if eq (include "generic.workloadType" .) "cronjob" }}
{{- fail "ingress.enabled cannot be used with workload.type 'cronjob' because CronJobs do not render a Service." }}
{{- end }}
{{- if not .Values.service.enabled }}
{{- fail "ingress.enabled requires service.enabled to be true." }}
{{- end }}
{{- if not .Values.ingress.hosts }}
{{- fail "ingress.enabled requires at least one ingress.hosts entry." }}
{{- end }}
{{- range .Values.ingress.hosts }}
{{- if not .paths }}
{{- fail (printf "ingress host '%s' requires at least one path." .host) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate ServiceMonitor dependencies.
*/}}
{{- define "generic.validateServiceMonitor" -}}
{{- if .Values.serviceMonitor.enabled }}
{{- if eq (include "generic.workloadType" .) "cronjob" }}
{{- fail "serviceMonitor.enabled cannot be used with workload.type 'cronjob' because CronJobs do not render a Service." }}
{{- end }}
{{- if not .Values.service.enabled }}
{{- fail "serviceMonitor.enabled requires service.enabled to be true." }}
{{- end }}
{{- if and (not .Values.serviceMonitor.endpoints) (not .Values.service.ports) }}
{{- fail "serviceMonitor.enabled requires service.ports or serviceMonitor.endpoints." }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate Service configuration.
*/}}
{{- define "generic.validateService" -}}
{{- if and .Values.service.enabled (ne (include "generic.workloadType" .) "cronjob") }}
{{- if not .Values.service.ports }}
{{- fail "service.enabled requires at least one service.ports entry." }}
{{- end }}
{{- if eq .Values.service.type "ExternalName" }}
{{- if not .Values.service.externalName }}
{{- fail "service.type ExternalName requires service.externalName." }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate Helm test configuration.
*/}}
{{- define "generic.validateTests" -}}
{{- if and .Values.tests.enabled .Values.service.enabled (ne (include "generic.workloadType" .) "cronjob") }}
{{- if and (not .Values.tests.args) .Values.tests.servicePortName }}
{{- $found := false }}
{{- range .Values.service.ports }}
{{- if eq .name $.Values.tests.servicePortName }}
{{- $found = true }}
{{- end }}
{{- end }}
{{- if not $found }}
{{- fail (printf "tests.servicePortName '%s' must match one of service.ports[].name." .Values.tests.servicePortName) }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Validate RBAC configuration.
*/}}
{{- define "generic.validateRBAC" -}}
{{- range $idx, $role := .Values.rbac.roles }}
{{- if not $role.rules }}
{{- fail (printf "rbac.roles[%d] (%s) is missing required field 'rules'." $idx $role.name) }}
{{- end }}
{{- if eq (len $role.rules) 0 }}
{{- fail (printf "rbac.roles[%d] (%s) has empty 'rules' - at least one rule is required." $idx $role.name) }}
{{- end }}
{{- range $ruleIdx, $rule := $role.rules }}
{{- if not $rule.verbs }}
{{- fail (printf "rbac.roles[%d].rules[%d] is missing required field 'verbs'." $idx $ruleIdx) }}
{{- end }}
{{- end }}
{{- end }}
{{- if .Values.rbac.clusterRole.enabled }}
{{- if not .Values.rbac.clusterRole.rules }}
{{- fail "rbac.clusterRole is enabled but missing required field 'rules'." }}
{{- end }}
{{- if eq (len .Values.rbac.clusterRole.rules) 0 }}
{{- fail "rbac.clusterRole is enabled but has empty 'rules' - at least one rule is required." }}
{{- end }}
{{- range $ruleIdx, $rule := .Values.rbac.clusterRole.rules }}
{{- if not $rule.verbs }}
{{- fail (printf "rbac.clusterRole.rules[%d] is missing required field 'verbs'." $ruleIdx) }}
{{- end }}
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
{{- if and .Values.storage.enabled (ne .Values.storage.volumeMode "Block") }}
- name: storage
  mountPath: {{ .Values.storage.mountPath }}
  {{- with .Values.storage.subPath }}
  subPath: {{ . }}
  {{- end }}
{{- end }}
{{- range .Values.configFiles }}
{{- if not (and (hasKey . "name") (hasKey . "mountPath") (hasKey . "content")) }}
{{- fail "configFiles entries require 'name', 'mountPath', and 'content' keys" }}
{{- end }}
- name: config-volume
  mountPath: {{ .mountPath }}
  subPath: {{ .name }}
{{- end }}
{{- range .Values.secretFiles }}
{{- if not (and (hasKey . "name") (hasKey . "mountPath") (hasKey . "content")) }}
{{- fail "secretFiles entries require 'name', 'mountPath', and 'content' keys" }}
{{- end }}
- name: secret-volume
  mountPath: {{ .mountPath }}
  subPath: {{ .name }}
{{- end }}
{{- with .Values.pod.volumeMounts }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Generate volume devices for main container.
*/}}
{{- define "generic.volumeDevices" -}}
{{- if and .Values.storage.enabled (eq .Values.storage.volumeMode "Block") }}
- name: storage
  devicePath: {{ .Values.storage.devicePath }}
{{- end }}
{{- with .Values.pod.volumeDevices }}
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
{{- $seen := dict }}
{{- range .files }}
{{- if hasKey $seen .name }}
{{- fail (printf "configFiles: duplicate name '%s'. Each entry must have a unique name." .name) }}
{{- end }}
{{- $_ := set $seen .name true }}
{{ .name }}: |
{{- include "generic.tplValue" (dict "value" .content "context" $global) | nindent 2 }}
{{- end }}
{{- end }}

{{/*
Generate Secret data entries from secretFiles.
*/}}
{{- define "generic.secretData" -}}
{{- $global := .context }}
{{- $seen := dict }}
{{- range .files }}
{{- if hasKey $seen .name }}
{{- fail (printf "secretFiles: duplicate name '%s'. Each entry must have a unique name." .name) }}
{{- end }}
{{- $_ := set $seen .name true }}
{{ .name }}: |
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
  {{- with .Values.lifecycle }}
  lifecycle:
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
  {{- $volumeDevices := include "generic.volumeDevices" . }}
  {{- if $volumeDevices }}
  volumeDevices:
    {{- $volumeDevices | nindent 4 }}
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
{{- end }}
serviceAccountName: {{ include "generic.serviceAccountName" . }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- with .Values.pod.priorityClassName }}
priorityClassName: {{ . }}
{{- end }}
{{- with .Values.pod.runtimeClassName }}
runtimeClassName: {{ . }}
{{- end }}
{{- if .Values.pod.hostNetwork }}
hostNetwork: true
{{- end }}
{{- if .Values.pod.hostPID }}
hostPID: true
{{- end }}
{{- if .Values.pod.hostIPC }}
hostIPC: true
{{- end }}
{{- if .Values.pod.shareProcessNamespace }}
shareProcessNamespace: true
{{- end }}
{{- if not (kindIs "invalid" .Values.pod.terminationGracePeriodSeconds) }}
terminationGracePeriodSeconds: {{ .Values.pod.terminationGracePeriodSeconds }}
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

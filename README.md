# generic

![Version: 2.0.0](https://img.shields.io/badge/Version-2.0.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: 2.0.0](https://img.shields.io/badge/AppVersion-2.0.0-informational?style=flat-square)

A flexible, generic Helm chart for deploying any containerized application to Kubernetes

## Features

- **Multiple Workload Types** - Deployment, StatefulSet, DaemonSet, or CronJob with explicit `workload.type` selector
- **Validation** - Fail-fast with clear error messages for invalid configurations
- **Multi-port Services** - Configure multiple container and service ports
- **Sidecar Containers** - Add init containers and sidecars to your pods
- **Multi-backend Ingress** - Route different paths to different services
- **Environment Variables** - Support for direct env vars, secretEnv, and envFrom
- **Config/Secret Mounting** - Mount configuration files with automatic pod rollover on changes
- **HorizontalPodAutoscaler** - With CPU, memory, and custom metrics support
- **PodDisruptionBudget** - Ensure high availability during disruptions
- **NetworkPolicy** - Control pod network traffic
- **ServiceMonitor** - Prometheus Operator integration
- **RBAC** - Multiple Roles and ClusterRole support with multi-namespace bindings

## Requirements

Kubernetes: `>=1.23.0-0`

## Installation

```bash
# Install with default values (Deployment with nginx)
helm install my-release generic

# Install with custom values
helm install my-release generic -f values.yaml

# Install in specific namespace
helm install my-release generic -n production --create-namespace
```

## Quick Start Examples

### Basic Deployment

```yaml
workload:
  type: deployment
  replicas: 2

image:
  repository: nginx
  tag: "1.25"

ports:
  - name: http
    containerPort: 80

service:
  ports:
    - name: http
      port: 80
      targetPort: 80
```

### StatefulSet with Persistent Storage

```yaml
workload:
  type: statefulset
  replicas: 3
  statefulset:
    podManagementPolicy: Parallel
    volumeClaimTemplates:
      - name: data
        size: 50Gi
        storageClassName: gp3

image:
  repository: postgres
  tag: "15"

ports:
  - name: postgres
    containerPort: 5432
```

### DaemonSet for Node-level Services

```yaml
workload:
  type: daemonset

image:
  repository: fluent/fluent-bit
  tag: "2.1"

pod:
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      effect: NoSchedule
```

### CronJob for Scheduled Tasks

```yaml
workload:
  type: cronjob
  cronjob:
    schedule: "0 2 * * *"
    concurrencyPolicy: Forbid

image:
  repository: curlimages/curl
  tag: "8.1.0"

command: ["/bin/sh", "-c"]
args: ["curl -X POST https://api.example.com/backup"]

service:
  enabled: false
```

### Multi-port Service

```yaml
ports:
  - name: http
    containerPort: 80
  - name: grpc
    containerPort: 9090

service:
  ports:
    - name: http
      port: 80
      targetPort: 80
    - name: grpc
      port: 9090
      targetPort: 9090
```

### With Sidecar Containers

```yaml
pod:
  initContainers:
    - name: init-config
      image: busybox
      command: ["sh", "-c", "cp /config/* /app/"]

  sidecars:
    - name: log-shipper
      image: fluent/fluent-bit:2.1
      resources:
        limits:
          memory: 64Mi
```

### Multi-backend Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt
  hosts:
    - host: api.example.com
      paths:
        - path: /api
          pathType: Prefix
        - path: /admin
          pathType: Prefix
          serviceName: admin-service
          servicePort: 8080
  tls:
    - secretName: api-tls
      hosts:
        - api.example.com
```

### Configuration Files

```yaml
configFiles:
  - name: app-config
    mountPath: /etc/app/config.yaml
    content: |
      database:
        host: localhost
        port: 5432

secretFiles:
  - name: credentials
    mountPath: /etc/app/credentials.json
    content: |
      {"apiKey": "secret-value"}

secretEnv:
  - name: DB_PASSWORD
    value: "super-secret"
```

### Environment from Existing Secrets

```yaml
envFrom:
  - secretRef:
      name: my-existing-secret
  - configMapRef:
      name: my-existing-configmap
```

### Production Configuration

```yaml
workload:
  type: deployment
  replicas: 3

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  metrics:
    cpu:
      enabled: true
      averageUtilization: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 2

networkPolicy:
  enabled: true
  policyTypes:
    - Ingress

serviceMonitor:
  enabled: true
  path: /metrics
```

### RBAC Configuration

```yaml
serviceAccount:
  create: true
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::123456789:role/my-role

rbac:
  roles:
    - name: my-app-role
      namespaces:
        - default
        - production
      rules:
        - apiGroups: [""]
          resources: ["configmaps"]
          verbs: ["get", "list", "watch"]

  clusterRole:
    enabled: true
    rules:
      - apiGroups: [""]
        resources: ["nodes"]
        verbs: ["get", "list"]
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| args | list | `[]` | Override container args |
| autoscaling.annotations | object | `{}` | HPA annotations |
| autoscaling.behavior | object | `{}` | HPA scaling behavior configuration |
| autoscaling.enabled | bool | `false` | Enable HorizontalPodAutoscaler (only for deployment/statefulset) |
| autoscaling.maxReplicas | int | `10` | Maximum number of replicas |
| autoscaling.metrics | object | `{"cpu":{"averageUtilization":80,"enabled":true},"custom":[],"memory":{"averageUtilization":80,"enabled":false}}` | Scaling metrics configuration |
| autoscaling.metrics.cpu.averageUtilization | int | `80` | Target CPU utilization percentage |
| autoscaling.metrics.cpu.enabled | bool | `true` | Enable CPU-based autoscaling |
| autoscaling.metrics.custom | list | `[]` | Custom metrics for HPA |
| autoscaling.metrics.memory.averageUtilization | int | `80` | Target memory utilization percentage |
| autoscaling.metrics.memory.enabled | bool | `false` | Enable memory-based autoscaling |
| autoscaling.minReplicas | int | `1` | Minimum number of replicas |
| command | list | `[]` | Override container command (entrypoint) |
| configFiles | list | `[]` | Config files to mount into pod (creates ConfigMap). Content is templated. |
| configFilesMode | int | `420` | File mode for mounted config files (octal) |
| env | list | `[]` | Environment variables for the main container |
| envFrom | list | `[]` | Load environment from existing ConfigMaps or Secrets |
| extraObjects | list | `[]` | Extra Kubernetes objects to deploy (fully templated) |
| fullnameOverride | string | `""` | Override full release name |
| globalAnnotations | object | `{}` | Global annotations added to ALL resources |
| image.pullPolicy | string | `"IfNotPresent"` | Image pull policy: Always, IfNotPresent, or Never |
| image.repository | string | `"nginx"` | Container image repository |
| image.tag | string | `""` | Container image tag (defaults to Chart.appVersion if empty) |
| imagePullSecrets | list | `[]` | Image pull secrets for private registries |
| ingress.annotations | object | `{}` | Ingress annotations |
| ingress.className | string | `""` | Ingress class name |
| ingress.enabled | bool | `false` | Enable Ingress |
| ingress.hosts | list | `[]` | Ingress hosts configuration |
| ingress.tls | list | `[]` | TLS configuration |
| livenessProbe | object | `{}` | Liveness probe configuration |
| nameOverride | string | `""` | Override chart name in resource names |
| networkPolicy.annotations | object | `{}` | NetworkPolicy annotations |
| networkPolicy.egress | list | `[]` | Egress rules |
| networkPolicy.enabled | bool | `false` | Enable NetworkPolicy |
| networkPolicy.ingress | list | `[]` | Ingress rules |
| networkPolicy.policyTypes | list | `["Ingress","Egress"]` | Policy types to enforce |
| pod.affinity | object | `{}` | Affinity rules for pod scheduling |
| pod.annotations | object | `{}` | Additional annotations for pods |
| pod.dnsConfig | object | `{}` | Custom DNS configuration |
| pod.dnsPolicy | string | `"ClusterFirst"` | DNS policy: ClusterFirst, ClusterFirstWithHostNet, Default, or None |
| pod.initContainers | list | `[]` | Init containers to run before main container |
| pod.labels | object | `{}` | Additional labels for pods |
| pod.nodeSelector | object | `{}` | Node selector for pod scheduling |
| pod.securityContext | object | `{}` | Pod-level security context |
| pod.sidecars | list | `[]` | Sidecar containers running alongside main container |
| pod.terminationGracePeriodSeconds | int | `30` | Termination grace period in seconds |
| pod.tolerations | list | `[]` | Tolerations for pod scheduling |
| pod.topologySpreadConstraints | list | `[]` | Topology spread constraints |
| pod.volumeMounts | list | `[]` | Additional volume mounts for main container |
| pod.volumes | list | `[]` | Additional volumes (beyond configFiles/secretFiles/storage) |
| podDisruptionBudget.annotations | object | `{}` | PDB annotations |
| podDisruptionBudget.enabled | bool | `false` | Enable PodDisruptionBudget (not supported for cronjob) |
| podDisruptionBudget.minAvailable | int | `1` | Minimum available pods (number or percentage) |
| ports | list | `[{"containerPort":80,"name":"http","protocol":"TCP"}]` | Container ports configuration |
| rbac.clusterRole | object | `{"enabled":false,"name":"","rules":[]}` | Cluster-scoped role configuration |
| rbac.clusterRole.enabled | bool | `false` | Enable ClusterRole creation |
| rbac.clusterRole.name | string | `""` | ClusterRole name (defaults to fullname) |
| rbac.clusterRole.rules | list | `[]` | ClusterRole rules |
| rbac.roles | list | `[]` | Namespace-scoped roles (creates Role + RoleBinding for each) |
| readinessProbe | object | `{}` | Readiness probe configuration |
| resources | object | `{}` | Resource limits and requests |
| restartOnConfigChange | bool | `true` | Restart pods automatically when configFiles or secretFiles change |
| secretEnv | list | `[]` | Secret environment variables (creates Secret and injects as env vars). Values are templated. |
| secretFiles | list | `[]` | Secret files to mount into pod (creates Secret). Content is templated. |
| secretFilesMode | int | `416` | File mode for mounted secret files (octal) |
| securityContext | object | `{}` | Security context for the main container |
| service.annotations | object | `{}` | Service annotations |
| service.enabled | bool | `true` | Enable Service creation |
| service.ports | list | `[{"name":"http","port":80,"protocol":"TCP","targetPort":80}]` | Service ports configuration |
| service.type | string | `"ClusterIP"` | Service type: ClusterIP, NodePort, LoadBalancer, or ExternalName |
| serviceAccount.annotations | object | `{}` | Annotations for the service account (e.g., for IAM roles) |
| serviceAccount.automountServiceAccountToken | bool | `true` | Automount API credentials into pods |
| serviceAccount.create | bool | `true` | Create a service account |
| serviceAccount.name | string | `""` | Service account name (defaults to fullname if empty) |
| serviceMonitor.annotations | object | `{}` | ServiceMonitor annotations |
| serviceMonitor.enabled | bool | `false` | Enable ServiceMonitor (requires Prometheus Operator) |
| serviceMonitor.endpoints | list | `[]` | Override default endpoints configuration |
| serviceMonitor.interval | string | `"30s"` | Scrape interval |
| serviceMonitor.labels | object | `{}` | Additional labels for ServiceMonitor discovery |
| serviceMonitor.path | string | `"/metrics"` | Metrics endpoint path |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout |
| startupProbe | object | `{}` | Startup probe configuration |
| storage.accessModes | list | `["ReadWriteOnce"]` | Access modes for PVC |
| storage.annotations | object | `{}` | PVC annotations |
| storage.enabled | bool | `false` | Enable persistent storage (creates PVC) |
| storage.mountPath | string | `"/data"` | Mount path in container |
| storage.name | string | `""` | PVC name (defaults to fullname-storage if empty) |
| storage.retainOnDelete | bool | `true` | Retain PVC when helm release is deleted |
| storage.selector | object | `{}` | Label selector for binding to existing PV |
| storage.size | string | `"10Gi"` | Storage size |
| storage.storageClassName | string | `""` | Storage class name (empty = default) |
| storage.subPath | string | `""` | SubPath within the volume to mount |
| storage.volumeMode | string | `"Filesystem"` | Volume mode: Filesystem or Block |
| workload.cronjob | object | `{"concurrencyPolicy":"Forbid","failedJobsHistoryLimit":1,"restartPolicy":"OnFailure","schedule":"0 * * * *","successfulJobsHistoryLimit":3,"timeZone":""}` | CronJob-specific settings (only used when type: cronjob) |
| workload.cronjob.concurrencyPolicy | string | `"Forbid"` | Concurrency policy: Allow, Forbid, or Replace |
| workload.cronjob.failedJobsHistoryLimit | int | `1` | Number of failed jobs to retain |
| workload.cronjob.restartPolicy | string | `"OnFailure"` | Restart policy for pods: OnFailure or Never |
| workload.cronjob.schedule | string | `"0 * * * *"` | Cron schedule expression |
| workload.cronjob.successfulJobsHistoryLimit | int | `3` | Number of successful jobs to retain |
| workload.cronjob.timeZone | string | `""` | Timezone for schedule (requires K8s >= 1.27) |
| workload.daemonset | object | `{"updateStrategy":{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}}` | DaemonSet-specific settings (only used when type: daemonset) |
| workload.daemonset.updateStrategy | object | `{"rollingUpdate":{"maxUnavailable":1},"type":"RollingUpdate"}` | Update strategy for DaemonSet |
| workload.deployment | object | `{"strategy":{"rollingUpdate":{"maxSurge":"25%","maxUnavailable":"25%"},"type":"RollingUpdate"}}` | Deployment-specific settings (only used when type: deployment) |
| workload.replicas | int | `1` | Number of replicas (ignored for daemonset and cronjob) |
| workload.statefulset | object | `{"podManagementPolicy":"OrderedReady","serviceName":"","updateStrategy":{"type":"RollingUpdate"},"volumeClaimTemplates":[]}` | StatefulSet-specific settings (only used when type: statefulset) |
| workload.statefulset.podManagementPolicy | string | `"OrderedReady"` | Pod management policy: OrderedReady or Parallel |
| workload.statefulset.serviceName | string | `""` | Service name for StatefulSet (defaults to fullname if empty) |
| workload.statefulset.updateStrategy | object | `{"type":"RollingUpdate"}` | Update strategy for StatefulSet |
| workload.statefulset.volumeClaimTemplates | list | `[]` | Volume claim templates for StatefulSet |
| workload.type | string | `"deployment"` | Workload type: deployment, statefulset, daemonset, or cronjob |

## Validation Rules

The chart validates configurations and fails with clear error messages:

| Condition | Error |
|-----------|-------|
| Invalid `workload.type` | Must be: deployment, statefulset, daemonset, cronjob |
| HPA with daemonset/cronjob | HPA only supports deployment and statefulset |
| PDB with cronjob | PDB cannot be used with cronjob |

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| vuongq | <quocvuongus@gmail.com> | <https://vuonghq.tech> |

## License

MIT

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

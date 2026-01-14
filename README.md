# generic

![Version: 1.1.0](https://img.shields.io/badge/Version-1.1.0-informational?style=flat-square) ![Type: application](https://img.shields.io/badge/Type-application-informational?style=flat-square) ![AppVersion: v1.1.0](https://img.shields.io/badge/AppVersion-v1.1.0-informational?style=flat-square)

A flexible, generic Helm chart for deploying any containerized application to Kubernetes

## Features

- **Deployment or StatefulSet** - Choose the workload type that fits your application
- **Multi-port Services** - Configure multiple container and service ports
- **Sidecar Containers** - Add additional containers to your pods
- **Multi-backend Ingress** - Route different paths to different services
- **Environment Variables** - Support for direct env vars, secrets, and envFrom
- **Config/Secret Mounting** - Mount configuration files with automatic pod rollover
- **HorizontalPodAutoscaler** - With custom metrics and scaling behavior
- **PodDisruptionBudget** - Ensure high availability during disruptions
- **NetworkPolicy** - Control pod network traffic
- **ServiceMonitor** - Prometheus Operator integration
- **RBAC** - Role and ClusterRole support with multi-namespace bindings

## Requirements

Kubernetes: `>=1.19.0-0`

## Installation

```bash
helm install my-release generic -f values.yaml
```

## Quick Start Examples

### Basic Deployment

```yaml
replicaCount: 2

image:
  repository: nginx
  tag: "1.25"

pod:
  ports:
    - name: http
      containerPort: 80

service:
  ports:
    - name: http
      port: 80
      targetPort: 80
```

### Multi-port Service

```yaml
pod:
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
  ports:
    - name: http
      containerPort: 8080
  containers:
    - name: redis
      image: redis:7
      ports:
        - name: redis
          containerPort: 6379
```

### Multi-backend Ingress

```yaml
ingress:
  enabled: true
  className: nginx
  hosts:
    - host: api.example.com
      paths:
        - path: /api
          pathType: Prefix
        - path: /web
          pathType: Prefix
          serviceName: web-frontend
          servicePort: 3000
```

### Environment from Existing Secrets

```yaml
pod:
  envFrom:
    - secretRef:
        name: my-existing-secret
    - configMapRef:
        name: my-existing-configmap
```

### StatefulSet with Storage

```yaml
statefulset:
  enabled: true
  serviceName: my-app

storage:
  create: true
  size: 10Gi
  mountPath: /data
```

### Production Configuration

```yaml
replicaCount: 3

podDisruptionBudget:
  enabled: true
  minAvailable: 2

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

networkPolicy:
  enabled: true
  policyTypes:
    - Ingress

serviceMonitor:
  enabled: true
  path: /metrics

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi
```

## Values

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| affinity | object | `{}` |  |
| args | list | `[]` | args for the pod's primary container. Default is the container's default "command" |
| autoscaling.behavior | object | `{}` | HPA behavior configuration for scale up/down |
| autoscaling.customMetrics | list | `[]` | Custom metrics for HPA (evaluated as-is) |
| autoscaling.enabled | bool | `false` |  |
| autoscaling.maxReplicas | int | `100` |  |
| autoscaling.minReplicas | int | `1` |  |
| autoscaling.targetCPUUtilizationPercentage | int | `80` |  |
| command | list | `[]` | command for the pod's primary container. Default is the container's default entrypoint |
| extraObjects | list | `[]` | Extra kubernetes objects to deploy (value evaluted as a template) |
| fullnameOverride | string | `""` |  |
| image.pullPolicy | string | `"IfNotPresent"` |  |
| image.repository | string | `"nginx"` |  |
| image.tag | string | `""` | Overrides the image tag whose default is the chart appVersion. |
| imagePullSecrets | list | `[]` |  |
| includeMountLabel | bool | `true` | whether to include the checksum/config and checksum/secret mount labels that automatically force pod rollover on config change |
| ingress.annotations | object | `{}` |  |
| ingress.className | string | `""` |  |
| ingress.enabled | bool | `false` |  |
| ingress.hosts[0].host | string | `"chart-example.local"` |  |
| ingress.hosts[0].paths[0].path | string | `"/"` |  |
| ingress.hosts[0].paths[0].pathType | string | `"Prefix"` |  |
| ingress.tls | list | `[]` |  |
| livenessProbe | object | `{}` | customize the primary container's livenessProbe. Default none |
| mountConfig | list | `[]` | an array of name, mountPath, and content keys that will be used to create configMap entries and mount them as files into the pod. Strings evaluated as a template |
| mountConfigMode | int | `420` | The file mode to use for mounting the mountConfig |
| mountSecret | list | `[]` | an array of name, mountPath, and content keys that will be used to create configMap entries and mount them into the pod. Strings evaluated as a template |
| mountSecretMode | int | `416` | The file mode to use for mounting the secretConfig |
| nameOverride | string | `""` |  |
| networkPolicy | object | `{"egress":[],"enabled":false,"ingress":[],"policyTypes":["Ingress","Egress"]}` | Network Policy configuration |
| networkPolicy.egress | list | `[]` | Egress rules (evaluated as-is) |
| networkPolicy.ingress | list | `[]` | Ingress rules (evaluated as-is) |
| networkPolicy.policyTypes | list | `["Ingress","Egress"]` | Policy types to enforce |
| nodeSelector | object | `{}` |  |
| pod.annotations | object | `{}` | Additional annotations to add to the pods |
| pod.containers | list | `[]` | Additional containers (sidecars) running alongside the main container |
| pod.env | list | `[]` |  |
| pod.envFrom | list | `[]` | Load environment variables from existing secrets or configmaps |
| pod.initContainers | list | `[]` |  |
| pod.labels | object | `{}` | Additional labels to add to the pods |
| pod.ports | list | `[{"containerPort":80,"name":"http","protocol":"TCP"}]` | Container ports configuration |
| pod.securityContext | object | `{}` |  |
| pod.volumeMounts | list | `[]` |  |
| pod.volumes | list | `[]` |  |
| podDisruptionBudget | object | `{"enabled":false,"minAvailable":1}` | Pod Disruption Budget configuration |
| podDisruptionBudget.minAvailable | int | `1` | Minimum number/percentage of pods that must remain available |
| rbac.clusterRole.name | string | `""` | The name for the ClusterRole. If empty, the "chart fullname" is used. |
| rbac.clusterRole.rules | list | `[]` | Rules used as-is in the creation of a ClusterRole |
| rbac.role.name | string | `""` | The name for the created role(s). If empty, the "chart fullname" is used. |
| rbac.role.rules | list | `[]` | Rule(s) used as-is in the creation of Role(s) |
| rbac.role.targetNamespaces | list | `[]` | The namespaces to create roles in. If empty, the Release.Namespace will be used by default. |
| readinessProbe | object | `{}` | customize the primary container's readinessProbe. Default is httpGet on the default `http` port |
| replicaCount | int | `1` |  |
| resources | object | `{}` |  |
| secretEnv | list | `[]` | an array of name, value keys that will be used to create secret entries and attach as environment variables. Values evaluated as a template |
| securityContext | object | `{}` |  |
| service.ports | list | `[{"name":"http","port":80,"protocol":"TCP","targetPort":80}]` | Service ports configuration |
| service.type | string | `"ClusterIP"` |  |
| serviceAccount.annotations | object | `{}` | Annotations to add to the service account |
| serviceAccount.create | bool | `true` | Specifies whether a service account should be created |
| serviceAccount.name | string | `""` | If not set and create is true, a name is generated using the fullname template |
| serviceMonitor | object | `{"annotations":{},"enabled":false,"endpoints":[],"interval":"30s","labels":{},"path":"/metrics","scrapeTimeout":"10s"}` | ServiceMonitor configuration for Prometheus Operator |
| serviceMonitor.annotations | object | `{}` | Annotations for ServiceMonitor |
| serviceMonitor.endpoints | list | `[]` | Custom endpoints (overrides default configuration) |
| serviceMonitor.interval | string | `"30s"` | Scrape interval |
| serviceMonitor.labels | object | `{}` | Additional labels for ServiceMonitor |
| serviceMonitor.path | string | `"/metrics"` | Metrics path |
| serviceMonitor.scrapeTimeout | string | `"10s"` | Scrape timeout |
| startupProbe | object | `{}` | customize the primary container's startupProbe. Default none |
| statefulset.enabled | bool | `false` |  |
| statefulset.podManagementPolicy | string | `"OrderedReady"` | Pod management policy: OrderedReady or Parallel |
| statefulset.serviceName | string | `"generic"` |  |
| statefulset.updateStrategy | object | `{"type":"RollingUpdate"}` | Update strategy for StatefulSet |
| statefulset.volumeClaimTemplates | list | `[]` | Volume claim templates for StatefulSet |
| storage.accessModes[0] | string | `"ReadWriteOnce"` |  |
| storage.annotations | object | `{}` | Additional annotations for PVC |
| storage.create | bool | `false` |  |
| storage.mountPath | string | `"/mnt/storage"` |  |
| storage.name | string | `""` |  |
| storage.requests.storage | string | `"6Gi"` |  |
| storage.retainOnDelete | bool | `true` | Retain PVC when helm release is deleted |
| storage.selector | object | `{}` | Label selector for binding to existing PV |
| storage.size | string | `""` | Storage size (preferred over requests.storage) |
| storage.storageClassName | string | `""` |  |
| storage.subPath | string | `""` | SubPath within the volume to mount |
| storage.volumeMode | string | `"Filesystem"` | Volume mode: Filesystem or Block |
| tolerations | list | `[]` |  |

## Upgrading

### From < 1.1.0

Port configuration structure changed:

**Before:**
```yaml
pod:
  containerPort: 80
  otherContainers: []
service:
  port: 80
  name: http
```

**After:**
```yaml
pod:
  ports:
    - name: http
      containerPort: 80
  containers: []
service:
  ports:
    - name: http
      port: 80
      targetPort: 80
```

## Maintainers

| Name | Email | Url |
| ---- | ------ | --- |
| vuongq | <quocvuongus@gmail.com> | <https://vuonghq.tech> |

----------------------------------------------
Autogenerated from chart metadata using [helm-docs v1.14.2](https://github.com/norwoodj/helm-docs/releases/v1.14.2)

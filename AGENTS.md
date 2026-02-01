# Generic Helm Chart - Agent Guide

## Project Overview

This is a **flexible, generic Helm chart** for deploying any containerized application to Kubernetes. It supports multiple workload types (Deployment, StatefulSet, DaemonSet, CronJob) through a unified configuration interface.

- **Chart Name**: generic
- **Version**: 2.0.0
- **App Version**: 2.0.0
- **Kubernetes**: >=1.23.0-0
- **License**: MIT
- **Author**: Quoc Vuong (quocvuongus@gmail.com)
- **Repository**: https://github.com/quocvuong92/helm-generic

## Project Structure

```
.
├── Chart.yaml              # Chart metadata, version, dependencies
├── values.yaml             # Default configuration values
├── values.schema.json      # JSON schema for values validation
├── README.md               # Auto-generated documentation (do not edit directly)
├── README.md.gotmpl        # Template for generating README.md
├── .helmignore             # Files to exclude from Helm packages
├── LICENSE                 # MIT license
├── ci/                     # CI test value files
│   ├── minimal-values.yaml
│   ├── deployment-full-values.yaml
│   ├── statefulset-values.yaml
│   ├── daemonset-values.yaml
│   ├── cronjob-values.yaml
│   ├── sidecars-values.yaml
│   └── storage-values.yaml
└── templates/              # Kubernetes resource templates
    ├── _helpers.tpl        # Shared helper templates (12 modules)
    ├── NOTES.txt           # Post-installation notes
    ├── configmap.yaml      # ConfigMap for configFiles
    ├── cronjob.yaml        # CronJob workload
    ├── daemonset.yaml      # DaemonSet workload
    ├── deployment.yaml     # Deployment workload
    ├── extra-objects.yaml  # Extra custom resources
    ├── hpa.yaml            # HorizontalPodAutoscaler
    ├── ingress.yaml        # Ingress
    ├── networkpolicy.yaml  # NetworkPolicy
    ├── pdb.yaml            # PodDisruptionBudget
    ├── pvc.yaml            # PersistentVolumeClaim
    ├── rbac.yaml           # RBAC (Role, RoleBinding, ClusterRole)
    ├── secret.yaml         # Secret for secretFiles and secretEnv
    ├── service.yaml        # Service
    ├── serviceaccount.yaml # ServiceAccount
    ├── servicemonitor.yaml # ServiceMonitor (Prometheus)
    └── statefulset.yaml    # StatefulSet workload
```

## Technology Stack

- **Helm 3** - Package manager for Kubernetes
- **Go Templates** - Templating language (`.tpl` files)
- **JSON Schema** - Values validation (`values.schema.json`)
- **helm-docs** - Documentation generation tool

## Key Features

1. **Multiple Workload Types**: deployment, statefulset, daemonset, cronjob
2. **Configuration Validation**: Fail-fast with clear error messages
3. **Auto-restart on Config Change**: Pods restart when configFiles/secretFiles change
4. **Multi-port Services**: Support for multiple container and service ports
5. **Sidecar Containers**: Init containers and sidecars support
6. **Autoscaling**: HPA with CPU, memory, and custom metrics
7. **RBAC**: Multiple Roles and ClusterRole with multi-namespace bindings
8. **Monitoring**: Prometheus ServiceMonitor integration
9. **Security**: NetworkPolicy, PodDisruptionBudget, SecurityContext

## Build and Test Commands

### Documentation Generation
```bash
# Regenerate README.md from README.md.gotmpl (requires helm-docs)
helm-docs

# Or with custom template
helm-docs --template-files=README.md.gotmpl
```

### Linting and Validation
```bash
# Lint the chart
helm lint .

# Lint with specific values file
helm lint . -f ci/deployment-full-values.yaml

# Validate values against schema
helm template my-release . --dry-run
```

### Testing Templates
```bash
# Render templates with default values
helm template my-release .

# Render with specific test values
helm template my-release . -f ci/statefulset-values.yaml
helm template my-release . -f ci/daemonset-values.yaml
helm template my-release . -f ci/cronjob-values.yaml

# Render with custom values
helm template my-release . -f my-values.yaml
```

### Packaging
```bash
# Create Helm package
helm package .

# Package with specific version
helm package . --version 2.0.1
```

## Code Style Guidelines

### Template Organization
The `_helpers.tpl` file is organized into **12 modules**:
1. **MODULE 1**: Naming (name, fullname, chart, serviceAccountName)
2. **MODULE 2**: Validation (workloadType, isWorkloadType, validateHPA, validatePDB)
3. **MODULE 3**: Metadata (labels, selectorLabels, annotations, podLabels)
4. **MODULE 4**: Image (image with tag/digest support)
5. **MODULE 5**: Template Rendering (tplValue)
6. **MODULE 6**: Environment Variables (env with secretEnv)
7. **MODULE 7**: Container Ports
8. **MODULE 8**: Volumes and Volume Mounts
9. **MODULE 9**: Config/Secret Data
10. **MODULE 10**: Main Container
11. **MODULE 11**: Pod Spec
12. **MODULE 12**: StatefulSet Helpers

### Naming Conventions
- All helper templates use prefix `generic.` (e.g., `generic.name`, `generic.labels`)
- Use camelCase for value keys in `values.yaml`
- Use hyphenated names for template files

### Labeling Standards
All resources use consistent Kubernetes labels:
```yaml
helm.sh/chart: {{ include "generic.chart" . }}
app.kubernetes.io/name: {{ include "generic.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
app.kubernetes.io/version: {{ .Chart.AppVersion }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
```

### Template Best Practices
1. Use `{{-` and `-}}` for whitespace control
2. Use `nindent` for proper indentation when including templates
3. Always validate input with `fail` function for clear error messages
4. Use `with` blocks for optional configuration sections
5. Check for empty values before rendering sections

## Configuration Patterns

### Workload Type Selection
```yaml
workload:
  type: deployment  # deployment, statefulset, daemonset, or cronjob
  replicas: 3
```

### Config Files (Creates ConfigMap)
```yaml
configFiles:
  - name: app-config
    mountPath: /etc/app/config.yaml
    content: |
      key: value
```

### Secret Environment Variables
```yaml
secretEnv:
  - name: DB_PASSWORD
    value: "secret-value"  # Value is templated
```

### Sidecars and Init Containers
```yaml
pod:
  initContainers:
    - name: init-config
      image: busybox
      command: ["sh", "-c", "echo init"]
  sidecars:
    - name: log-shipper
      image: fluent/fluent-bit:2.1
```

## Testing Strategy

### CI Test Files
The `ci/` directory contains test value files for different scenarios:

| File | Tests |
|------|-------|
| `minimal-values.yaml` | Default values, basic deployment |
| `deployment-full-values.yaml` | Deployment with all features |
| `statefulset-values.yaml` | StatefulSet with VolumeClaimTemplates |
| `daemonset-values.yaml` | DaemonSet with tolerations, hostPath |
| `cronjob-values.yaml` | CronJob with schedule, no service |
| `sidecars-values.yaml` | Init containers, sidecars, extra volumes |
| `storage-values.yaml` | PVC creation, storage mounting |

### Validation Rules
The chart enforces these validation rules (fail-fast):

| Condition | Error |
|-----------|-------|
| Invalid `workload.type` | Must be: deployment, statefulset, daemonset, cronjob |
| HPA with daemonset/cronjob | HPA only supports deployment and statefulset |
| PDB with cronjob | PDB cannot be used with cronjob |
| Missing configFiles/secretFiles keys | Entries require 'mountPath' and 'content' keys |
| Missing secretEnv keys | Entries require both 'name' and 'value' keys |

### JSON Schema Validation
All values are validated against `values.schema.json` before template rendering.

## Security Considerations

### Default Security Settings
- Default file mode for configFiles: `0644` (octal: 420)
- Default file mode for secretFiles: `0640` (octal: 416)
- Service account token automount enabled by default (configurable)
- PVC retention on delete enabled by default (`retainOnDelete: true`)

### RBAC Configuration
```yaml
rbac:
  roles:
    - name: my-role
      namespaces: [default, production]  # Multi-namespace support
      rules:
        - apiGroups: [""]
          resources: ["pods"]
          verbs: ["get", "list"]
  clusterRole:
    enabled: true
    rules: []
```

### Pod Security
```yaml
pod:
  securityContext:
    fsGroup: 2000
    runAsNonRoot: true

securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  readOnlyRootFilesystem: true
```

## Common Tasks

### Adding a New Workload Type
1. Add validation in `_helpers.tpl` MODULE 2
2. Create new template file (e.g., `templates/job.yaml`)
3. Add workload type to values schema in `values.schema.json`
4. Update `values.yaml` with default configuration
5. Add CI test file in `ci/`
6. Regenerate README with `helm-docs`

### Adding a New Template Helper
1. Determine appropriate module in `_helpers.tpl`
2. Follow existing naming convention: `generic.<helperName>`
3. Add documentation comment with usage example
4. Test with `helm template`

### Updating Values Schema
1. Edit `values.schema.json`
2. Ensure all required fields are marked
3. Use proper types and validation constraints
4. Test with `helm lint`

### Adding CI Test Scenario
1. Create new file in `ci/` directory
2. Include comment describing what it tests
3. Use realistic example values
4. Test with `helm template my-release . -f ci/<new-file>.yaml`

## Important Notes

- **DO NOT edit README.md directly** - Edit `README.md.gotmpl` and run `helm-docs`
- **Always validate** configurations with `helm lint` before committing
- **Test all workload types** when modifying shared helpers
- **Maintain backward compatibility** when adding new features
- **Update values.schema.json** when adding new configuration options

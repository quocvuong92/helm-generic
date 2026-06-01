# Invalid Helm Values

These files intentionally fail rendering or linting. Use them to verify chart
validation messages stay clear and stable.

## Fixture Categories

- **cronjob-\*** - CronJob-specific validation (ingress conflicts, timezone version gates)
- **deployment-\*** - Deployment field type validation (string vs integer)
- **externalname-\*** - ExternalName service validation
- **hpa-\*** - HorizontalPodAutoscaler validation (metrics, min/max replicas)
- **ingress-\*** - Ingress validation (empty hosts)
- **pod-\*** - Pod spec validation (label selector overrides)
- **rbac-\*** - RBAC validation (missing/empty rules, missing verbs)
- **servicemonitor-\*** - ServiceMonitor dependency validation
- **storage-\*** - Storage validation (block device paths)
- **tests-\*** - Test pod validation (service port names)

## Special Cases

- `cronjob-timezone-old-k8s.yaml` - Requires `--kube-version 1.26.0` flag to trigger failure (timezone needs K8s 1.27+)

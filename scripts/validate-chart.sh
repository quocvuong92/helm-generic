#!/usr/bin/env bash
set -euo pipefail

chart_dir="${1:-.}"
notes_file="$chart_dir/templates/NOTES.txt"

valid_values=(
  "ci/minimal-values.yaml"
  "ci/deployment-full-values.yaml"
  "ci/statefulset-values.yaml"
  "ci/daemonset-values.yaml"
  "ci/cronjob-values.yaml"
  "ci/storage-values.yaml"
  "ci/storage-block-values.yaml"
  "ci/pdb-zero-values.yaml"
  "ci/hpa-custom-null-cpu-values.yaml"
  "ci/sidecars-values.yaml"
  "ci/configfiles-collision-values.yaml"
  "ci/externalname-values.yaml"
)

helm lint "$chart_dir"

for values_file in "${valid_values[@]}"; do
  helm lint "$chart_dir" -f "$values_file"
  helm template review "$chart_dir" -f "$values_file" >/dev/null
done

# Validate ci/valid/ fixtures (edge cases that must render successfully)
if compgen -G "ci/valid/*.yaml" >/dev/null; then
  for values_file in ci/valid/*.yaml; do
    helm template review "$chart_dir" -f "$values_file" >/dev/null
  done
fi

if [[ -f "$notes_file" ]]; then
  if ! grep -q 'generic.hasValue.*minAvailable' "$notes_file"; then
    echo "NOTES.txt must render podDisruptionBudget.minAvailable when the value is 0" >&2
    exit 1
  fi

  if ! grep -q 'generic.hasValue.*maxUnavailable' "$notes_file"; then
    echo "NOTES.txt must render podDisruptionBudget.maxUnavailable when the value is 0" >&2
    exit 1
  fi
fi

if compgen -G "ci/invalid/*.yaml" >/dev/null; then
  for values_file in ci/invalid/*.yaml; do
    # Skip timezone fixture - tested separately with --kube-version
    if [[ "$values_file" == *"cronjob-timezone-old-k8s.yaml" ]]; then
      continue
    fi
    if helm template review "$chart_dir" -f "$values_file" >/tmp/helm-generic-invalid.out 2>&1; then
      echo "Expected invalid fixture to fail: $values_file" >&2
      cat /tmp/helm-generic-invalid.out >&2
      exit 1
    fi
  done
fi

# CronJob timezone requires K8s 1.27+ - must fail on older versions
if [[ -f "ci/invalid/cronjob-timezone-old-k8s.yaml" ]]; then
  if helm template review "$chart_dir" -f "ci/invalid/cronjob-timezone-old-k8s.yaml" --kube-version 1.26.0 >/tmp/helm-generic-invalid.out 2>&1; then
    echo "Expected cronjob-timezone-old-k8s.yaml to fail on K8s 1.26" >&2
    cat /tmp/helm-generic-invalid.out >&2
    exit 1
  fi
  # Must succeed on K8s 1.27+
  helm template review "$chart_dir" -f "ci/invalid/cronjob-timezone-old-k8s.yaml" --kube-version 1.27.0 >/dev/null
fi

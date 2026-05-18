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
    if helm template review "$chart_dir" -f "$values_file" >/tmp/helm-generic-invalid.out 2>&1; then
      echo "Expected invalid fixture to fail: $values_file" >&2
      cat /tmp/helm-generic-invalid.out >&2
      exit 1
    fi
  done
fi

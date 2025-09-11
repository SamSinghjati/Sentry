#!/bin/bash

SENTRY_NAMESPACE="${1:-sentry}" 
SCRIPT_DIR=$(dirname "$(realpath "$0")")
VALUES_FILE="${SCRIPT_DIR}/values.yaml"
SENTRY_VERSION="v27.2.4"

check_requirements() {
  echo "Checking requirements..."
  command -v yq >/dev/null 2>&1 || { echo >&2 "'yq' is required. Install: https://github.com/mikefarah/yq"; exit 1; }
  command -v helm >/dev/null 2>&1 || { echo >&2 "'helm' is required. Install: https://helm.sh/docs/intro/install/"; exit 1; }
  echo "All requirements found."
}

prepare_install() {
  check_requirements

  # Add Sentry Helm repo 
  helm repo add sentry https://sentry-kubernetes.github.io/charts
  helm repo update

  OUTPUT_DIR="manifests"
  rm -rf "${OUTPUT_DIR}"
  mkdir -p "${OUTPUT_DIR}"

  # Render templates using default values.yaml from chart
  helm template sentry sentry/sentry \
  --create-namespace \
  --namespace="${SENTRY_NAMESPACE}" \
  --values "${VALUES_FILE}" \
  --version "${SENTRY_VERSION}" \
  --output-dir "${OUTPUT_DIR}"

  # Create namespace manifest
  cat <<EOF > namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ${SENTRY_NAMESPACE}
EOF

  # Create kustomization.yaml
  cat <<EOF > kustomization.yaml
resources:
- namespace.yaml

namespace: ${SENTRY_NAMESPACE}
EOF

  # Process all YAML files
  for file in $(find ./manifests -name '*.yaml'); do
    # Add to kustomization.yaml
    yq -i '.resources += "'${file}'"' kustomization.yaml

    # Remove Helm labels
    yq -i 'del(.metadata.labels."helm.sh/chart")' "${file}"
    yq -i 'del(.metadata.labels."app.kubernetes.io/managed-by")' "${file}"
    yq -i 'del(.spec.template.metadata.labels."helm.sh/chart")' "${file}"
    yq -i 'del(.spec.template.metadata.labels."app.kubernetes.io/managed-by")' "${file}"
  done

  echo "Sentry manifests generated in: ${OUTPUT_DIR}"
  echo "Apply with: kubectl apply -k ."
}

main() {
  prepare_install
}

main

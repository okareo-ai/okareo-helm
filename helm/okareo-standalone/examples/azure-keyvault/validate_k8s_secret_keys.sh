#!/usr/bin/env bash

set -euo pipefail

AKS_NAMESPACE="${AKS_NAMESPACE:-okareo}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-okareo-app-secrets}"

required_keys=(
  DB_USER
  DB_PASSWORD
  DB_NAME
  DATABASE_URL
  TENANT_DB
  EVAL_API_KEY
  VLLM_API_KEY
  OKAREO_JWT_PRIVATE_KEY
)

echo "Checking secret '$K8S_SECRET_NAME' in namespace '$AKS_NAMESPACE'..."

if ! kubectl -n "$AKS_NAMESPACE" get secret "$K8S_SECRET_NAME" >/dev/null 2>&1; then
  echo "ERROR: Secret '$K8S_SECRET_NAME' not found in namespace '$AKS_NAMESPACE'."
  exit 1
fi

missing=0
for key in "${required_keys[@]}"; do
  if ! kubectl -n "$AKS_NAMESPACE" get secret "$K8S_SECRET_NAME" -o "jsonpath={.data.$key}" | grep -q .; then
    echo "MISSING: $key"
    missing=1
  else
    echo "OK: $key"
  fi
done

if [[ "$missing" -ne 0 ]]; then
  echo "Validation failed: one or more required keys are missing."
  exit 1
fi

echo "Validation passed: all required keys are present."

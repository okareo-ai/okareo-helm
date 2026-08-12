#!/usr/bin/env bash

set -euo pipefail

# Required inputs
: "${KEYVAULT_NAME:?Set KEYVAULT_NAME}"

# Optional inputs
AKS_NAMESPACE="${AKS_NAMESPACE:-okareo}"
K8S_SECRET_NAME="${K8S_SECRET_NAME:-okareo-app-secrets}"

# Key Vault secret name overrides
KV_DB_USER="${KV_DB_USER:-db-user}"
KV_DB_PASSWORD="${KV_DB_PASSWORD:-db-password}"
KV_DB_NAME="${KV_DB_NAME:-db-name}"
KV_DATABASE_URL="${KV_DATABASE_URL:-database-url}"
KV_TENANT_DB="${KV_TENANT_DB:-tenant-db}"
KV_EVAL_API_KEY="${KV_EVAL_API_KEY:-eval-api-key}"
KV_VLLM_API_KEY="${KV_VLLM_API_KEY:-vllm-api-key}"
KV_OKAREO_JWT_PRIVATE_KEY="${KV_OKAREO_JWT_PRIVATE_KEY:-okareo-jwt-private-key}"

fetch_kv_secret() {
  local keyvault_secret_name="$1"
  az keyvault secret show \
    --vault-name "$KEYVAULT_NAME" \
    --name "$keyvault_secret_name" \
    --query value \
    -o tsv
}

echo "Reading secrets from Key Vault '$KEYVAULT_NAME'..."

DB_USER="$(fetch_kv_secret "$KV_DB_USER")"
DB_PASSWORD="$(fetch_kv_secret "$KV_DB_PASSWORD")"
DB_NAME="$(fetch_kv_secret "$KV_DB_NAME")"
DATABASE_URL="$(fetch_kv_secret "$KV_DATABASE_URL")"
TENANT_DB="$(fetch_kv_secret "$KV_TENANT_DB")"
EVAL_API_KEY="$(fetch_kv_secret "$KV_EVAL_API_KEY")"
VLLM_API_KEY="$(fetch_kv_secret "$KV_VLLM_API_KEY")"
OKAREO_JWT_PRIVATE_KEY="$(fetch_kv_secret "$KV_OKAREO_JWT_PRIVATE_KEY")"

echo "Upserting Kubernetes Secret '$K8S_SECRET_NAME' in namespace '$AKS_NAMESPACE'..."

kubectl -n "$AKS_NAMESPACE" create secret generic "$K8S_SECRET_NAME" \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=TENANT_DB="$TENANT_DB" \
  --from-literal=EVAL_API_KEY="$EVAL_API_KEY" \
  --from-literal=VLLM_API_KEY="$VLLM_API_KEY" \
  --from-literal=OKAREO_JWT_PRIVATE_KEY="$OKAREO_JWT_PRIVATE_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done. Secret '$K8S_SECRET_NAME' is ready for Helm existingSecretName."

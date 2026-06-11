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
KV_FRONTEGG_API_KEY="${KV_FRONTEGG_API_KEY:-frontegg-api-key}"
KV_FRONTEGG_DOMAIN="${KV_FRONTEGG_DOMAIN:-frontegg-domain}"
KV_FRONTEGG_API_GATEWAY_URL="${KV_FRONTEGG_API_GATEWAY_URL:-frontegg-api-gateway-url}"
KV_FRONTEGG_WEBHOOK_KEY="${KV_FRONTEGG_WEBHOOK_KEY:-frontegg-webhook-key}"
KV_FRONTEGG_PUBLIC_KEY="${KV_FRONTEGG_PUBLIC_KEY:-frontegg-public-key}"
KV_FRONTEGG_CLIENT_ID="${KV_FRONTEGG_CLIENT_ID:-frontegg-client-id}"

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
FRONTEGG_API_KEY="$(fetch_kv_secret "$KV_FRONTEGG_API_KEY")"
FRONTEGG_DOMAIN="$(fetch_kv_secret "$KV_FRONTEGG_DOMAIN")"
FRONTEGG_API_GATEWAY_URL="$(fetch_kv_secret "$KV_FRONTEGG_API_GATEWAY_URL")"
FRONTEGG_WEBHOOK_KEY="$(fetch_kv_secret "$KV_FRONTEGG_WEBHOOK_KEY")"
FRONTEGG_PUBLIC_KEY="$(fetch_kv_secret "$KV_FRONTEGG_PUBLIC_KEY")"
FRONTEGG_CLIENT_ID="$(fetch_kv_secret "$KV_FRONTEGG_CLIENT_ID")"

echo "Upserting Kubernetes Secret '$K8S_SECRET_NAME' in namespace '$AKS_NAMESPACE'..."

kubectl -n "$AKS_NAMESPACE" create secret generic "$K8S_SECRET_NAME" \
  --from-literal=DB_USER="$DB_USER" \
  --from-literal=DB_PASSWORD="$DB_PASSWORD" \
  --from-literal=DB_NAME="$DB_NAME" \
  --from-literal=DATABASE_URL="$DATABASE_URL" \
  --from-literal=TENANT_DB="$TENANT_DB" \
  --from-literal=EVAL_API_KEY="$EVAL_API_KEY" \
  --from-literal=VLLM_API_KEY="$VLLM_API_KEY" \
  --from-literal=FRONTEGG_API_KEY="$FRONTEGG_API_KEY" \
  --from-literal=FRONTEGG_DOMAIN="$FRONTEGG_DOMAIN" \
  --from-literal=FRONTEGG_API_GATEWAY_URL="$FRONTEGG_API_GATEWAY_URL" \
  --from-literal=FRONTEGG_WEBHOOK_KEY="$FRONTEGG_WEBHOOK_KEY" \
  --from-literal=FRONTEGG_PUBLIC_KEY="$FRONTEGG_PUBLIC_KEY" \
  --from-literal=FRONTEGG_CLIENT_ID="$FRONTEGG_CLIENT_ID" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "Done. Secret '$K8S_SECRET_NAME' is ready for Helm existingSecretName."

# Azure Key Vault -> Kubernetes Secret Workflow (AKS)

This example shows how to use Azure Key Vault as the source of truth and feed values into the Helm chart using `secrets.existingSecretName`.

`existingSecretName` must be a Kubernetes `Secret` name in your AKS namespace, not a Key Vault name.

## 1) Create Key Vault secrets

Use any naming convention you want. The helper script in this folder defaults to these Key Vault secret names:

- `db-user`
- `db-password`
- `db-name`
- `database-url`
- `tenant-db`
- `eval-api-key`
- `vllm-api-key`
- `okareo-jwt-private-key`

Example creation commands:

```bash
export KEYVAULT_NAME="<KEYVAULT_NAME>"

az keyvault secret set --vault-name "$KEYVAULT_NAME" --name db-user --value "<DB_USER>"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name db-password --value "<DB_PASSWORD>"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name db-name --value "<DB_NAME>"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name database-url --value "postgresql+psycopg2://<DB_USER>:<DB_PASSWORD>@<DB_HOST>:5432/<DB_NAME>?sslmode=require"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name tenant-db --value "postgresql+psycopg2://<DB_USER>:<DB_PASSWORD>@<DB_HOST>:5432/<DB_NAME>?sslmode=require"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name eval-api-key --value "<EVAL_API_KEY>"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name vllm-api-key --value "sk-none"
az keyvault secret set --vault-name "$KEYVAULT_NAME" --name okareo-jwt-private-key --value "$(openssl genrsa 2048 | openssl base64 -A)"
```

## 2) Sync Key Vault values into a Kubernetes Secret

Use the helper script below, or use your own secret-management path to populate the same keys into a Kubernetes Secret.

### One-shot sync script

The script below reads Key Vault secrets and upserts a Kubernetes Secret (default: `okareo-app-secrets` in namespace `okareo`).

```bash
export KEYVAULT_NAME="<KEYVAULT_NAME>"
export AKS_NAMESPACE="okareo"
export K8S_SECRET_NAME="okareo-app-secrets"

bash helm/okareo-standalone/examples/azure-keyvault/sync_keyvault_to_k8s_secret.sh
```

If your Key Vault secret names differ, override them with environment variables before running the script (for example `KV_DB_USER`, `KV_DATABASE_URL`, `KV_EVAL_API_KEY`).

## 3) Point Helm at the existing Kubernetes Secret

Use the provided values snippet:

```bash
helm upgrade --install okareo helm/okareo-standalone \
  --namespace okareo \
  --create-namespace \
  -f /tmp/okareo-values.yaml \
  -f helm/okareo-standalone/examples/azure-keyvault/values-existing-secret.yaml
```

## 4) Validate required keys exist

```bash
export AKS_NAMESPACE="okareo"
export K8S_SECRET_NAME="okareo-app-secrets"

bash helm/okareo-standalone/examples/azure-keyvault/validate_k8s_secret_keys.sh
```

## Rotation behavior

When you rotate values in Key Vault:

- Run the sync script again, or update the Kubernetes Secret via your own automation path.

Because the app reads these values as env vars, restart workloads to pick up updates:

```bash
kubectl -n okareo rollout restart deployment/okareo-okareo-standalone-services
kubectl -n okareo rollout restart statefulset/okareo-okareo-standalone-db
```

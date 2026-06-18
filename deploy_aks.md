# AKS Deployment Guide (GitHub Actions + CLI)

This repository has a GitHub workflow that deploys backend and frontend services to your AKS clusters.

Run the orchestrated command below to deploy the full split standalone footprint automatically:
- backend cluster: services + external Redis + external NATS
- frontend cluster: frontend + ingress resources (served by ingress-nginx)

Orchestrated single-run workflow (recommended):

Placeholder guide:
- `<org>/<repo>`: GitHub repository that contains these workflows (typically `okareo-ai/okareo-helm`).
- `<backend-aks-rg>` / `<backend-aks-cluster>`: backend AKS resource group + cluster.
- `<frontend-aks-rg>` / `<frontend-aks-cluster>`: frontend AKS resource group + cluster.
- `<kubernetes-namespace>`: namespace used in both clusters.
- `<redis-release-name>` / `<nats-release-name>`: external dependency release names in backend cluster.
- `<app-domain>` / `<api-domain>`: public frontend and API hostnames routed by frontend ingress.

GitHub Actions-specific prerequisites:
- Workflow/secrets setup in `<org>/<repo>`:
  - Orchestrated workflow exists: `.github/workflows/deploy-aks-split-orchestrated.yml`
  - GitHub Secrets: `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
  - GitHub Secrets: `OKAREO_REGISTRY_SERVER`, `OKAREO_REGISTRY_USERNAME`, `OKAREO_REGISTRY_PASSWORD`
  - GitHub Variable: `OKAREO_VALUES_YAML` or `OKAREO_VALUES_YAML_B64`

```bash
gh workflow run deploy-aks-split-orchestrated.yml --repo <org>/<repo> \
  -f backend_aks_resource_group=<backend-aks-rg> \
  -f backend_aks_cluster_name=<backend-aks-cluster> \
  -f frontend_aks_resource_group=<frontend-aks-rg> \
  -f frontend_aks_cluster_name=<frontend-aks-cluster> \
  -f kubernetes_namespace=<kubernetes-namespace> \
  -f backend_release_name=okareo-services \
  -f frontend_release_name=okareo-frontend \
  -f backend_values_overlay_path=deploy/values/cluster-backend-services.example.yaml \
  -f frontend_values_overlay_template_path=deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml \
  -f redis_release_name=<redis-release-name> \
  -f redis_values_path=deploy/values/redis-ha-4node.servicepool.example.yaml \
  -f nats_release_name=<nats-release-name> \
  -f nats_values_path=deploy/values/nats-4node.servicepool.example.yaml \
  -f frontend_app_host=<app-domain> \
  -f frontend_api_host=<api-domain> \
  -f create_namespace=true \
  -f backend_helm_timeout=30m \
  -f frontend_helm_timeout=20m
```

And to watch each run:

Placeholder guide:
- `<org>/<repo>`: Same GitHub repo used for `gh workflow run`.
- `<run-id>`: Run identifier from `gh run list` output for `deploy-aks-split-orchestrated.yml`.

```bash
gh run list --repo <org>/<repo> --workflow "deploy-aks-split-orchestrated.yml" --limit 5
gh run watch <run-id> --repo <org>/<repo>
```

## Commands for deploying to AKS cluster (CLI)

```bash
cd ~/git/okareo-helm
export NS="okareo"
```

1) Create namespace and app secret

```bash
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -
kubectl -n "$NS" apply -f examples/okareo-app-secrets.example.yaml
```

For SSO mode, include `SSO_CLIENT_SECRET` in `examples/okareo-app-secrets.example.yaml`.

2) Prepare runtime values and cross-cluster frontend overlay

```bash
cp examples/okareo-values.example.yaml okareo-values.yaml
```

Update `okareo-values.yaml` with your tenant/runtime values.

Then edit `deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml` and replace:

- `<BACKEND_SERVICES_LB_IP>` with backend services LB IP
- `<BACKEND_NATS_LB_IP>` with backend NATS LB IP
- `app.example.com` / `api.example.com` and TLS secret names for your domains

### 2.5) Private network connectivity prerequisite (required for internal-only semitrusted mode)

If backend services/NATS are configured as Azure **internal** LoadBalancers, frontend cluster ingress must be able to reach backend private ILB IPs on ports `8000` and `4222`.

1. Discover AKS-managed VNet identities:

```bash
FRONTEND_RG="<frontend-aks-resource-group>"
FRONTEND_AKS="<frontend-aks-cluster-name>"
BACKEND_RG="<backend-aks-resource-group>"
BACKEND_AKS="<backend-aks-cluster-name>"

FRONTEND_NODE_RG="$(az aks show -g "$FRONTEND_RG" -n "$FRONTEND_AKS" --query nodeResourceGroup -o tsv)"
BACKEND_NODE_RG="$(az aks show -g "$BACKEND_RG" -n "$BACKEND_AKS" --query nodeResourceGroup -o tsv)"

FRONTEND_VNET_ID="$(az network vnet list -g "$FRONTEND_NODE_RG" --query '[0].id' -o tsv)"
BACKEND_VNET_ID="$(az network vnet list -g "$BACKEND_NODE_RG" --query '[0].id' -o tsv)"

FRONTEND_VNET_CIDR="$(az network vnet show --ids "$FRONTEND_VNET_ID" --query 'addressSpace.addressPrefixes[0]' -o tsv)"
BACKEND_VNET_CIDR="$(az network vnet show --ids "$BACKEND_VNET_ID" --query 'addressSpace.addressPrefixes[0]' -o tsv)"

printf "frontend node RG: %s\nbackend node RG: %s\n" "$FRONTEND_NODE_RG" "$BACKEND_NODE_RG"
printf "frontend vnet: %s (%s)\nbackend vnet: %s (%s)\n" "$FRONTEND_VNET_ID" "$FRONTEND_VNET_CIDR" "$BACKEND_VNET_ID" "$BACKEND_VNET_CIDR"
```

2. Ensure address spaces **do not overlap** before peering:

```bash
python3 - <<'PY'
import ipaddress, os, sys
f = ipaddress.ip_network(os.environ['FRONTEND_VNET_CIDR'])
b = ipaddress.ip_network(os.environ['BACKEND_VNET_CIDR'])
print(f"frontend={f} backend={b}")
if f.overlaps(b):
    print("ERROR: VNet CIDRs overlap; VNet peering for private routing will not work.")
    sys.exit(1)
print("OK: non-overlapping CIDRs")
PY
```

3. Create bidirectional VNet peering:

```bash
FRONTEND_VNET_NAME="$(az network vnet show --ids "$FRONTEND_VNET_ID" --query name -o tsv)"
BACKEND_VNET_NAME="$(az network vnet show --ids "$BACKEND_VNET_ID" --query name -o tsv)"

az network vnet peering create \
  --resource-group "$FRONTEND_NODE_RG" \
  --vnet-name "$FRONTEND_VNET_NAME" \
  --name "to-${BACKEND_AKS}" \
  --remote-vnet "$BACKEND_VNET_ID" \
  --allow-vnet-access \
  --allow-forwarded-traffic

az network vnet peering create \
  --resource-group "$BACKEND_NODE_RG" \
  --vnet-name "$BACKEND_VNET_NAME" \
  --name "to-${FRONTEND_AKS}" \
  --remote-vnet "$FRONTEND_VNET_ID" \
  --allow-vnet-access \
  --allow-forwarded-traffic
```

4. Verify peering status is `Connected`:

```bash
az network vnet peering list -g "$FRONTEND_NODE_RG" --vnet-name "$FRONTEND_VNET_NAME" -o table
az network vnet peering list -g "$BACKEND_NODE_RG" --vnet-name "$BACKEND_VNET_NAME" -o table
```

5. If required by NSG policy, allow frontend subnet to backend ILB ports (`8000`,`4222`):

```bash
FRONTEND_SUBNET_ID="$(az network vnet subnet list -g "$FRONTEND_NODE_RG" --vnet-name "$FRONTEND_VNET_NAME" --query '[0].id' -o tsv)"
BACKEND_SUBNET_ID="$(az network vnet subnet list -g "$BACKEND_NODE_RG" --vnet-name "$BACKEND_VNET_NAME" --query '[0].id' -o tsv)"

FRONTEND_SUBNET_PREFIX="$(az network vnet subnet show --ids "$FRONTEND_SUBNET_ID" --query addressPrefix -o tsv)"
BACKEND_SUBNET_NSG_ID="$(az network vnet subnet show --ids "$BACKEND_SUBNET_ID" --query networkSecurityGroup.id -o tsv)"

BACKEND_SUBNET_NSG_NAME="$(basename "$BACKEND_SUBNET_NSG_ID")"

az network nsg rule create \
  --resource-group "$BACKEND_NODE_RG" \
  --nsg-name "$BACKEND_SUBNET_NSG_NAME" \
  --name AllowFrontendToBackendServices8000 \
  --priority 300 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "$FRONTEND_SUBNET_PREFIX" \
  --destination-port-ranges 8000

az network nsg rule create \
  --resource-group "$BACKEND_NODE_RG" \
  --nsg-name "$BACKEND_SUBNET_NSG_NAME" \
  --name AllowFrontendToBackendNats4222 \
  --priority 301 \
  --direction Inbound \
  --access Allow \
  --protocol Tcp \
  --source-address-prefixes "$FRONTEND_SUBNET_PREFIX" \
  --destination-port-ranges 4222
```

6. Validate private reachability from frontend cluster (after backend ILBs exist):

```bash
BACKEND_SERVICES_PRIVATE_ILB_IP="<BACKEND_SERVICES_PRIVATE_ILB_IP>"
BACKEND_NATS_PRIVATE_ILB_IP="<BACKEND_NATS_PRIVATE_ILB_IP>"

kubectl --context <frontend-kube-context> -n okareo run netcheck-http --image=curlimages/curl:8.8.0 --rm -it --restart=Never -- \
  sh -c "curl -m 10 -sS -o /dev/null -w 'services:%{http_code} %{time_total}\\n' http://${BACKEND_SERVICES_PRIVATE_ILB_IP}:8000/v0/health"

kubectl --context <frontend-kube-context> -n okareo run netcheck-nats --image=nicolaka/netshoot:latest --rm -it --restart=Never -- \
  sh -c "nc -vz -w 5 ${BACKEND_NATS_PRIVATE_ILB_IP} 4222"
```

For internal-only semitrusted mode:

- Use backend **private ILB IPs** for `<BACKEND_SERVICES_LB_IP>` and `<BACKEND_NATS_LB_IP>`.
- Confirm frontend cluster can route to backend private ILB IPs on `8000` and `4222` (VNet peering + NSG rules).

3) Install external dependencies (Redis + NATS) in backend cluster

```bash
helm upgrade --install okareo-redis-ha ./helm/okareo-redis-ha \
  -n "$NS" --create-namespace \
  -f deploy/values/redis-ha-4node.servicepool.example.yaml

helm repo add nats https://nats-io.github.io/k8s/helm/charts/
helm repo update
helm upgrade --install okareo-nats nats/nats \
  -n "$NS" --create-namespace \
  -f deploy/values/nats-4node.servicepool.example.yaml
```

4) Deploy backend services release

```bash
helm upgrade --install okareo-services ./helm/okareo-standalone \
  -n "$NS" --create-namespace \
  -f okareo-values.yaml \
  -f deploy/values/cluster-backend-services.example.yaml \
  --wait --timeout 30m
```

Optional SSO config in `examples/okareo-values.example.yaml`:

- `services.extraEnv`: set `OKAREO_STANDALONE_AUTH_MODE=sso`, `SSO_ISSUER_URL`, `SSO_CLIENT_ID`
- `frontend.extraEnv`: set `OKAREO_STANDALONE_AUTH_MODE=sso`

5) Read backend LoadBalancer IPs for cross-cluster frontend overlay

```bash
# services LoadBalancer IP (for crossClusterApi.endpointIP)
kubectl -n "$NS" get svc \
  -l app.kubernetes.io/instance=okareo-services,app.kubernetes.io/component=services \
  -o wide

# nats LoadBalancer IP (for crossClusterNats.endpointIP)
kubectl -n "$NS" get svc \
  -l app.kubernetes.io/instance=okareo-nats \
  -o wide
```

If `EXTERNAL-IP` is `<pending>`, wait and retry.

For internal-only semitrusted mode on AKS, `EXTERNAL-IP` will be a private IP from your VNet (ILB).

6) Update cross-cluster frontend overlay with these IPs

- Set `crossClusterApi.endpointIP` to the backend services `EXTERNAL-IP`.
- Set `crossClusterNats.endpointIP` to the backend NATS `EXTERNAL-IP`.

7) Switch kubectl context to frontend cluster and deploy cross-cluster frontend release

```bash
kubectl config use-context <frontend-cluster-context>

helm upgrade --install okareo-frontend ./helm/okareo-standalone \
  -n "$NS" --create-namespace \
  -f okareo-values.yaml \
  -f deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml \
  --wait --timeout 20m
```

Optional: ingress-first single release

```bash
helm upgrade --install okareo ./helm/okareo-standalone \
  -n "$NS" --create-namespace \
  -f examples/okareo-values.example.yaml \
  -f examples/nginx-ingress.example.yaml \
  --wait --timeout 20m
```

Notes for ingress overlay:

- `examples/nginx-ingress.example.yaml` sets long-running services ingress upstream timeouts:
  - `nginx.ingress.kubernetes.io/proxy-connect-timeout: "30"`
  - `nginx.ingress.kubernetes.io/proxy-send-timeout: "300"`
  - `nginx.ingress.kubernetes.io/proxy-read-timeout: "7200"`
- On AKS with ingress-nginx, set the controller service annotation
  `service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz`
  to avoid Azure LB probing `/` and marking backends unhealthy.
- Custom endpoint TLS verification defaults to enabled.
- For split trust mode, prefer:
  - frontend via `deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml` (ingress + cross-cluster API/NATS upstreams)
  - backend services via `deploy/values/cluster-backend-services.example.yaml` (`services.service.type=LoadBalancer`)
- Dev-only self-signed escape hatch (temporary while migrating to CA-signed certs):
  - set `services.extraEnv`: `OKAREO_CUSTOM_ENDPOINT_SSL_VERIFY=false`
  - optional compat alias: `VERIFY_CUSTOM_ENDPOINT_SSL_CERT=false`

8) Validate

```bash
helm -n "$NS" list
kubectl -n "$NS" get deploy,svc
curl -sS -X POST "https://api.example.com/v0/health"
```

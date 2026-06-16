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

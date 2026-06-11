# Okareo Standalone Helm Chart

This chart deploys Okareo application components and now supports split-role deployments with component toggles.

For a cloud provider agnostic, step-by-step deployment guide, see:

- `https://okareo.com/docs/standalone/deploy-kubernetes`

## Components and toggles

- `frontend.enabled`
- `services.enabled`
- `redis.enabled`
- `nats.enabled`
- `db.enabled` (optional fallback PostgreSQL)

Default values keep all app components enabled for backward compatibility.

## Recommended architecture

For AKS dual-cluster trust split:

- Frontend cluster: deploy this chart with `frontend.enabled=true` and others disabled.
- Backend cluster: deploy this chart with `services.enabled=true`, `redis.enabled=false`, `nats.enabled=false`.
- Deploy Redis HA and NATS as separate Helm releases:
  - Redis: internal chart `helm/okareo-redis-ha`
  - NATS: official `nats/nats` chart clustered in `servicepool`

Example overlays in this repo:

- `examples/overlay-frontend-only.yaml`
- `examples/overlay-services-only.yaml`
- `examples/redis-ha-4node.servicepool.example.yaml`
- `examples/nats-4node.servicepool.example.yaml`

When using the GitHub Actions workflow for backend deployments, external
Redis HA and NATS installation is enabled by default. Relevant inputs:

- `deploy_external_redis_nats=true`
- `redis_chart_path=helm/okareo-redis-ha`
- `redis_values_path=examples/redis-ha-4node.servicepool.example.yaml`
- `nats_values_path=examples/nats-4node.servicepool.example.yaml`

## External Redis and NATS wiring for services-only mode

When deploying services-only mode with in-chart Redis/NATS disabled:

- Set `redis.external.host` (required if `services.enabled=true` and `redis.enabled=false`)
- Set `redis.external.port` (optional, default `6379`)
- Set `nats.server.url` (required if `services.enabled=true` and `nats.enabled=false`)

For legacy services images that hardcode `nats://nats:4222`, enable the compatibility shim
to create an internal alias service named `nats`:

- `nats.aliasService.enabled=true` (default)
- `nats.aliasService.name=nats`

For small fixed pools (for example 2-node `servicepool`) with strict services anti-affinity,
the chart defaults services rollout strategy to:

- `services.strategy.rollingUpdate.maxSurge=0`
- `services.strategy.rollingUpdate.maxUnavailable=1`

This avoids rollout deadlocks where an extra surge pod cannot be scheduled.

Template guards enforce these requirements.

## Host-based cross-cluster routing (frontend LB)

This chart can route API/NATS traffic through frontend-cluster ingress while backend
workloads stay in a backend cluster.

Use overlay:

- `examples/overlay-frontend-hostbased-crosscluster.yaml`

This enables:

- app host -> in-cluster frontend service
- api host -> cross-cluster API upstream via local Service+Endpoints
- nats TCP mapping (`4222`) via ingress-nginx `tcp-services` config map

Relevant values:

- `crossClusterApi.*`
- `crossClusterNats.*`
- `ingressNginxTcp.*`

## SSO configuration (OIDC)

Enable SSO by setting auth mode to `sso` in both services and frontend env.

Services (required for backend SSO flow):

- Use `services.extraEnv` for:
  - `OKAREO_STANDALONE_AUTH_MODE=sso`
  - `SSO_ISSUER_URL=<oidc issuer url>`
  - `SSO_CLIENT_ID=<oidc client id>`
  - Optional: `SSO_SCOPES`, `SSO_SESSION_MAX_SEC`, `SSO_ALLOWED_CLAIM`, `SSO_ALLOWED_VALUES`
- Provide `SSO_CLIENT_SECRET` from secret source:
  - `secretKeyRef` mode: set `secrets.ssoClientSecret` (or include `SSO_CLIENT_SECRET` in `secrets.existingSecretName`)
  - `envFile` mode: include `SSO_CLIENT_SECRET` in the mounted env file

Frontend (for browser auth mode):

- Use `frontend.extraEnv` for:
  - `OKAREO_STANDALONE_AUTH_MODE=sso`

Values example:

```yaml
services:
  extraEnv:
    - name: OKAREO_STANDALONE_AUTH_MODE
      value: sso
    - name: SSO_ISSUER_URL
      value: https://<OIDC_ISSUER_URL>
    - name: SSO_CLIENT_ID
      value: <OIDC_CLIENT_ID>
    - name: SSO_SCOPES
      value: openid email profile

frontend:
  extraEnv:
    - name: OKAREO_STANDALONE_AUTH_MODE
      value: sso
```

## Example: services-only chart deployment

```bash
helm upgrade --install okareo-services helm/okareo-standalone \
  --namespace okareo \
  --create-namespace \
  -f /tmp/okareo-values.yaml \
  -f examples/overlay-services-only.yaml
```

## Example: frontend-only chart deployment

```bash
helm upgrade --install okareo-frontend helm/okareo-standalone \
  --namespace okareo \
  --create-namespace \
  -f /tmp/okareo-values.yaml \
  -f examples/overlay-frontend-only.yaml
```

Your app-runtime values (`/tmp/okareo-values.yaml`) must include:

```yaml
redis:
  external:
    host: okareo-redis-ha-rw
    port: 6379

nats:
  server:
    url: nats://okareo-nats:4222
```

## Node-pool and resource guidance

Recommended defaults are documented in:

- `aks_uniform.plan.md`
- `NODE_POOL_CONFIGURATION.md`

In short:

- `frontendpool`: `2 vCPU / 8 GiB`, autoscaler `min=3`, `max=6`
- `servicepool`: `8 CPU / 32 GB`, autoscaler `min=max=3`
- `services` requests floor: `6000m` CPU and `28000Mi` memory

## Legacy single-cluster usage

If you still need a single-cluster deployment, keep all component toggles enabled and use the chart as before.

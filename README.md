# Okareo Helm (Cloud-Agnostic)

This repository is a minimal bundle for deploying Okareo standalone on Kubernetes.

The Kubernetes deployment can be achieved via GitHub Actions or the CLI. Quick starts for both are outlined below.

## Quick Start (Recommended Split Releases)

### Shared prerequisites (applies to both GitHub Actions and CLI)

- AKS cluster prerequisites:
  - Backend cluster has node pool `servicepool` (and matching toleration policy if used).
  - Frontend cluster has node pool `frontendpool` (and matching toleration policy if used).
  - Frontend cluster has an ingress controller installed. `ingress-nginx` is the documented example (guide: https://docs.okareo.com/standalone/deploy-kubernetes#2-ensure-ingress-controller), but other ingress controllers are supported if you adapt ingress class/annotations.
  - TLS is configured for frontend/API ingress. `cert-manager` + `ClusterIssuer` is recommended (guide: https://docs.okareo.com/standalone/tls), but manual/corporate-CA certificate provisioning is also supported.
  - DNS records for `app.<domain>` and `api.<domain>` point to the frontend ingress endpoint (create `A` records for static LB IPs or `CNAME` records for hostname endpoints, then verify resolution before frontend workflow). For temporary non-production testing, you can use IP/path-based routing, but host-based DNS is recommended for production.
- Values files used by these commands (bundled in this repo; review and customize before deploy):
  - `deploy/values/cluster-backend-services.example.yaml`
  - `deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml`
  - `deploy/values/redis-ha-4node.servicepool.example.yaml`
  - `deploy/values/nats-4node.servicepool.example.yaml`
- Runtime values content is prepared for `OKAREO_VALUES_YAML` / `OKAREO_VALUES_YAML_B64`:
  - Start from `examples/okareo-values.example.yaml`.
  - Replace required placeholders (at minimum tenant fields and model configuration placeholders such as `<TENANT_ID>`, `<DISPLAY_NAME>`, `<OKAREO_AIRGAP_TOKEN>`, and Azure model/resource placeholders).
  - Store the finalized file in GitHub Variables as plain YAML (`OKAREO_VALUES_YAML`) or base64 (`OKAREO_VALUES_YAML_B64`).
  - Recommended (base64):
    - `base64 -i okareo-values.yaml | tr -d '\n' | gh variable set OKAREO_VALUES_YAML_B64 --repo <org>/<repo> --body-file -`
  - Alternative (plain YAML):
    - `gh variable set OKAREO_VALUES_YAML --repo <org>/<repo> --body-file okareo-values.yaml`
- Cross-cluster frontend overlay is configured before frontend run:
  - Set `crossClusterApi.endpointIP` in `deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml` to the backend services LoadBalancer IP.
  - Set `crossClusterNats.endpointIP` in `deploy/values/cluster-frontend-hostbased-crosscluster.example.yaml` to the backend NATS LoadBalancer IP.
  - Set ingress hosts/TLS values in that same file for your frontend and API domains.

## Provider deployment guides

- AKS (GitHub Actions + CLI): [`deploy_aks.md`](./deploy_aks.md)
- GCP: Coming soon
- AWS: Coming soon

# platform/

Runs the app (built from [`/`](..) at the repo root) on Kubernetes with Prometheus + Grafana watching it — self-healing deployment, real metrics, a provisioned dashboard.

```
CI (repo root) → ECR image → kind cluster
                                ├── Deployment (3 replicas) → Service
                                ├── ConfigMap / Secret → env config
                                └── Prometheus (scrape /metrics) → Grafana (dashboard)
```

## Why local, not a live cluster

Keeping a Kubernetes cluster running 24/7 for a portfolio demo isn't realistic — this directory is built to be **spun up on demand and torn down**, same discipline as [`/infra`](../infra). Every claim below is backed by an actual verification run, not a screenshot.

## Reproduce it

```bash
kind create cluster --name shortline

# ECR is private — the cluster needs its own pull credentials (expires every 12h, see Known limitations)
kubectl create secret docker-registry ecr-secret \
  --docker-server=910929919817.dkr.ecr.ap-southeast-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password=$(aws ecr get-login-password --region ap-southeast-1)

kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/config.yaml

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

kubectl apply -f k8s/servicemonitor.yaml
kubectl apply -f k8s/grafana-dashboard.yaml
```

## Proof: self-healing under real load

`selfheal-test.sh` runs 100 requests through the **Service's actual routing** (not `kubectl port-forward`, which locks onto a single pod and gives a false negative) while deleting a backing pod mid-stream:

```
Deleting pod: shortline-66f7dd9bfd-mr8ws
--- response code counts (real Service routing) ---
    100 200
--- pods after ---
shortline-66f7dd9bfd-mwqvq   1/1   Running   2m25s
shortline-66f7dd9bfd-qscwr   1/1   Running   5m10s
shortline-66f7dd9bfd-xv64j   1/1   Running   13s     ← replacement pod
```

100/100 requests succeeded. A replacement pod was scheduled and ready within seconds.

## Proof: real metrics, scraped and queryable

`check-prometheus.sh` hits Prometheus's own API directly after generating traffic:

```
shortline_http_requests_total{route="/health",status="200",pod="shortline-...kknxr"} 27
shortline_http_requests_total{route="/shorten",status="200",pod="shortline-...vfj7d"} 19
shortline_http_requests_total{route="/:code",status="404",pod="shortline-...4zr6m"} 16
...
rate(shortline_http_requests_total[5m]) → non-zero per route/status/pod
```

`check-grafana.sh` confirms the dashboard (provisioned as code via `k8s/grafana-dashboard.yaml`, auto-imported by Grafana's ConfigMap sidecar — not clicked together by hand) is actually loaded:

```
{"uid":"shortline","title":"Shortline","url":"/d/shortline/shortline", ...}
```

## Known limitations

- **ECR pull secret expires every 12 hours** (it's a temporary token from `aws ecr get-login-password`). In a real production setup, nodes would instead assume an IAM role directly (e.g. IRSA on EKS) rather than relying on a manually refreshed secret — this directory uses the simpler token approach since it's local/on-demand, not always-on. Refresh with the same `kubectl create secret docker-registry ...` command if pods start showing `ErrImagePull`.
- No live public URL — see [`/infra`](../infra) for the actual AWS-hosted deployment target.

## Tech stack

Kubernetes (`kind`), kubectl, Helm, Prometheus, Grafana (dashboards as code), AWS ECR

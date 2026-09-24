# Shortline

![CI](https://github.com/JonathanHJR/Shortline/actions/workflows/ci.yml/badge.svg)

A URL shortener (`POST /shorten`, `GET /:code`) built as a vehicle for a full platform engineering pipeline — the app itself is deliberately small; the infrastructure around it is the point.

```
git push → GitHub Actions (test → build → OIDC-authenticated push to ECR)
                                              │
                    ┌─────────────────────────┴─────────────────────────┐
                    ▼                                                   ▼
            /platform (this repo)                              /infra (this repo)
       Kubernetes + Prometheus/Grafana                     Terraform + AWS (VPC, EC2)
        self-healing, dashboards-as-code                  reproducible on demand
```

## Structure

- **`/`** (this level) — the app itself: Express server, Dockerfile, CI/CD pipeline
- **`/platform`** — runs the app on Kubernetes locally, with real observability ([details](platform/README.md))
- **`/infra`** — provisions the AWS infrastructure the app runs on ([details](infra/README.md))
- **`/iam`** — the actual least-privilege IAM policies used to authenticate GitHub Actions to AWS via OIDC (no long-lived credentials stored anywhere)

## Run it locally

```bash
docker compose up
curl -X POST http://localhost:8081/shorten -H "Content-Type: application/json" -d '{"url":"https://example.com"}'
```

## CI/CD

Every push to `main` runs the test suite, then — only if tests pass — builds the image and pushes it to a private ECR repository. Authentication uses **OIDC federation**, not stored AWS credentials: GitHub issues a short-lived token, AWS's IAM trusts it only for this specific repo on this specific branch (see `iam/trust-policy.json`), and the permissions granted are scoped to exactly one action set on exactly one ECR repository (`iam/ecr-policy.json`) — no `ecr:*`, no standing access keys.

The ECR repository itself is owned by `/infra`'s Terraform, not left standing permanently — when it doesn't currently exist (i.e. `/infra` is torn down), CI builds and tests as normal but skips the push gracefully rather than failing, since there's nothing wrong with the commit, just nowhere to publish it right now.

## Why no live demo link

The app ships to a private ECR repo via that pipeline; the actual deployment targets (`/platform`'s Kubernetes cluster, `/infra`'s AWS EC2 instance) are both built to be **spun up on demand and torn down**, not left running 24/7 — a deliberate cost/operational tradeoff, not an oversight. Each subdirectory's README documents real, reproducible proof it works (actual command output, not screenshots).

## Tech stack

Node.js, Express, Docker (multi-stage builds), GitHub Actions, AWS (ECR, IAM/OIDC, and see `/infra` + `/platform` for more), Kubernetes, Prometheus, Grafana, Terraform

# infra/

The AWS infrastructure the app runs on, defined entirely as code — a VPC, subnet, security group, an EC2 instance, an ECR repository, and least-privilege IAM roles, all reproducible on demand and torn down when not needed.

```
ECR repository (shortline) ──────────────────┐
                                              │ pulled at boot
VPC (10.0.0.0/16)                            │
  └── public subnet → internet gateway → route table
        └── security group (inbound: app port only)
              └── EC2 instance (IAM role: SSM + scoped ECR pull, no long-lived keys)
                    └── docker run <ECR image>
```

## Status

Compute (VPC/EC2/IAM) is written and **validated** (`terraform init`, `validate`, and `plan` all succeed) but **not applied** — provisioning it is a deliberate, separate decision, not bundled into writing the code. The **ECR repository is imported and actively tracked** (`terraform import aws_ecr_repository.shortline shortline`) even though the rest hasn't been applied yet — see "Why ECR lives here" below for why that repo needed adopting now rather than later.

## Reproduce it

```bash
terraform init
terraform plan      # review the diff — 11 resources, nothing surprising
terraform apply      # provisions everything
curl $(terraform output -raw app_url)/health
terraform destroy    # tears it all down, including the ECR repository
```

## What `terraform plan` actually confirmed

```
data.aws_ami.al2023: Read complete after 1s [id=ami-02bec2fccd72ad1ab]
aws_ecr_repository.shortline: Refreshing state... [id=shortline]
...
Plan: 11 to add, 0 to change, 0 to destroy.
```

The AMI is resolved **dynamically** via a data source (`main.tf`), not hardcoded — avoids the classic "this AMI ID doesn't exist anymore" failure mode months later. The ECR repository shows zero drift, confirming the imported resource's definition (`ecr.tf`) exactly matches what's actually deployed.

## Why ECR lives here, not somewhere standalone

The repository was originally created with a one-off `aws ecr create-repository` CLI call, entirely outside Terraform's tracking — meaning `terraform destroy` would never have touched it, and it would keep accumulating a small storage cost indefinitely between sessions. `capstone`'s equivalent project has the exact same problem already solved (see its `eks.tf` comment on the OIDC provider it manages for the same reason), and its CI gracefully treats "the registry doesn't currently exist" as expected, not a failure — this repo now does the same: `ci.yml` checks `aws ecr describe-repositories` before pushing and skips (not fails) if `/infra` hasn't been applied.

## Design decisions worth explaining

- **IAM role, not access keys.** The EC2 instance authenticates to ECR using its own instance role (`compute.tf`) — same OIDC-adjacent principle as the CI pipeline's approach, no credentials stored anywhere. Unlike `/platform`'s local `kind` cluster (which needs a manually refreshed pull secret because it's not an AWS resource itself), this instance's role-based access never expires or needs refreshing.
- **No SSH port open.** Shell access goes through AWS Systems Manager (`AmazonSSMManagedInstanceCore` policy), not an open port 22 — the security group only allows the app's own port inbound.
- **Least-privilege ECR policy**, same pattern as `/iam/ecr-policy.json`: scoped to exactly the `shortline` repository, and to pull actions only (no push, no delete).

## Tech stack

Terraform, AWS (VPC, EC2, IAM, ECR)

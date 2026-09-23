# infra/

The AWS infrastructure the app runs on, defined entirely as code — a VPC, subnet, security group, an EC2 instance, and a least-privilege IAM role, all reproducible on demand and torn down when not needed.

```
VPC (10.0.0.0/16)
  └── public subnet → internet gateway → route table
        └── security group (inbound: app port only)
              └── EC2 instance (IAM role: SSM + scoped ECR pull, no long-lived keys)
                    └── docker run <ECR image>
```

## Status

Code is written and **validated** (`terraform init`, `validate`, and `plan` all succeed — see below) but has **not been applied**. Provisioning real AWS resources is a deliberate, separate decision, not something bundled into writing the code.

## Reproduce it

```bash
terraform init
terraform plan      # review the diff — 11 resources, nothing surprising
terraform apply      # provisions everything
curl $(terraform output -raw app_url)/health
terraform destroy    # tears it all down
```

## What `terraform plan` actually confirmed

```
data.aws_ami.al2023: Read complete after 1s [id=ami-02bec2fccd72ad1ab]
...
Plan: 11 to add, 0 to change, 0 to destroy.
```

The AMI is resolved **dynamically** via a data source (`main.tf`), not hardcoded — avoids the classic "this AMI ID doesn't exist anymore" failure mode months later.

## Design decisions worth explaining

- **IAM role, not access keys.** The EC2 instance authenticates to ECR using its own instance role (`compute.tf`) — same OIDC-adjacent principle as the CI pipeline's approach, no credentials stored anywhere. Unlike `/platform`'s local `kind` cluster (which needs a manually refreshed pull secret because it's not an AWS resource itself), this instance's role-based access never expires or needs refreshing.
- **No SSH port open.** Shell access goes through AWS Systems Manager (`AmazonSSMManagedInstanceCore` policy), not an open port 22 — the security group only allows the app's own port inbound.
- **Least-privilege ECR policy**, same pattern as `/iam/ecr-policy.json`: scoped to exactly the `shortline` repository, and to pull actions only (no push, no delete).

## Tech stack

Terraform, AWS (VPC, EC2, IAM, ECR)

# CLAUDE.md

## What This Repo Is

This is **terraform-aws-networking** — TenToZen's reusable Terraform module for AWS VPC networking. It creates a 3-tier VPC (public, app, data subnets) with optional NAT, Route53 private hosted zone, and S3 VPC endpoint.

This module is the foundation layer — all other AWS infrastructure (compute, observability, VPN) depends on it.

## Related Repos

| Repo | Relationship |
|------|-------------|
| [blueprints](https://github.com/tentozen/blueprints) | `aws/networking.md` — architectural principles this module implements |
| [runbooks](https://github.com/tentozen/runbooks) | `aws/lgtm/` and `aws/netbird/` modules consume this module's outputs |
| [dojo](https://github.com/tentozen/dojo) | `aws/networking/` — lab environment consumer of this module |

## Key Design Decisions

- CIDRs computed via `cidrsubnet()`, not hardcoded
- App subnets are /20 (EKS pod IP needs)
- Data subnets are isolated (no internet route)
- NAT is optional with a cost-conscious fck-nat alternative
- Private hosted zone for internal service DNS

## Standards

Follow these instruction files strictly:

- `.claude/instructions/ProjectStandards.md`
- `.claude/instructions/GithubIssuesWorkflow.md`

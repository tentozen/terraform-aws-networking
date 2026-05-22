# terraform-aws-networking

TenToZen's opinionated AWS networking module — 3-tier VPC with public, app, and data subnets, optional NAT, Route53 private hosted zone, and S3 VPC endpoint.

## Usage

```hcl
module "networking" {
  source = "git::git@github.com:tentozen/terraform-aws-networking.git?ref=v0.0.1"

  app_name        = "myapp"
  environment     = "prod"
  region          = "ap-south-1"
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["ap-south-1a"]
  internal_domain = "myapp.internal"
}
```

## What gets created

| Resource | Details |
|----------|---------|
| VPC | Single VPC with DNS support |
| Public subnets | /24 per AZ — ALB, NAT, public-facing services |
| App subnets | /20 per AZ — workloads, EKS nodes (large IP space for pods) |
| Data subnets | /24 per AZ — RDS, ElastiCache (isolated, no internet route) |
| Internet Gateway | Public subnet routing |
| NAT (optional) | Managed NAT Gateway or fck-nat (t4g.nano) per AZ |
| Route tables | Per tier, with appropriate routing |
| S3 VPC endpoint | Gateway endpoint on all route tables |
| Route53 private zone | Internal DNS (e.g. `myapp.internal`) |

## Variables

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `app_name` | string | (required) | Application name, used in resource naming |
| `environment` | string | (required) | Environment name (e.g. prod, lab) |
| `region` | string | (required) | AWS region |
| `vpc_cidr` | string | (required) | VPC CIDR block (e.g. 10.0.0.0/16) |
| `azs` | list(string) | (required) | Availability zones. Single for non-prod, multiple for prod |
| `deploy_nat` | bool | `true` | Deploy NAT for app subnet outbound internet |
| `use_fck_nat` | bool | `false` | Use fck-nat (~$3/mo) instead of managed NAT Gateway (~$32/mo) |
| `internal_domain` | string | (required) | Internal domain for Route53 private zone |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | Map of AZ → public subnet ID |
| `app_subnet_ids` | Map of AZ → app subnet ID |
| `data_subnet_ids` | Map of AZ → data subnet ID |
| `nat_public_ips` | Map of AZ → NAT EIP (empty if NAT disabled or using fck-nat) |
| `private_zone_id` | Route53 private hosted zone ID |
| `internal_domain` | Internal domain name |

## Design decisions

- **3-tier subnets** — public (ingress), app (workloads), data (databases). Data tier has no internet route.
- **cidrsubnet()** — all CIDRs computed from `vpc_cidr`, no hardcoding
- **/20 for app subnet** — EKS VPC CNI assigns a real VPC IP per pod, /24 is too small
- **NAT is optional** — `deploy_nat = false` skips NAT entirely. Use `use_fck_nat = true` for a ~$3/mo alternative to the ~$32/mo managed NAT Gateway.
- **S3 VPC endpoint** — gateway endpoint attached to all route tables, no internet hop for S3 traffic
- **Private hosted zone** — internal service discovery (e.g. `grafana.myapp.internal`)

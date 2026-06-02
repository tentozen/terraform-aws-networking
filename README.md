# terraform-aws-networking

TenToZen's opinionated AWS networking module — 3-tier VPC with public, app, and data subnets, optional NAT, optional proxy subnet for transparent egress control, SSM VPC endpoints, Route53 private hosted zone, and S3 VPC endpoint.

## Usage

```hcl
module "networking" {
  source = "git::git@github.com:tentozen/terraform-aws-networking.git?ref=v0.0.2"

  app_name        = "myapp"
  environment     = "prod"
  region          = "ap-south-1"
  vpc_cidr        = "10.0.0.0/16"
  azs             = ["ap-south-1a"]
  internal_domain = "myapp.internal"
}
```

### With egress proxy and SSM endpoints

```hcl
module "networking" {
  source = "git::git@github.com:tentozen/terraform-aws-networking.git?ref=v0.0.2"

  app_name             = "myapp"
  environment          = "prod"
  region               = "ap-south-1"
  vpc_cidr             = "10.0.0.0/16"
  azs                  = ["ap-south-1a"]
  internal_domain      = "myapp.internal"
  deploy_proxy_subnet    = true
  proxy_eni_id           = "eni-xxx"          # from egress-proxy terraform output
  deploy_ssm_endpoints   = true
  enable_dns_query_logging = true
}
```

## What gets created

| Resource | Details |
|----------|---------|
| VPC | Single VPC with DNS support |
| Public subnets | /24 per AZ — ALB, NAT, public-facing services |
| App subnets | /20 per AZ — workloads, EKS nodes (large IP space for pods) |
| Data subnets | /24 per AZ — RDS, ElastiCache (isolated, no internet route) |
| Proxy subnets (optional) | /24 per AZ — transparent egress proxy, routes to NAT |
| Internet Gateway | Public subnet routing |
| NAT (optional) | Managed NAT Gateway or fck-nat (t4g.nano) per AZ |
| Route tables | Per tier, with appropriate routing |
| S3 VPC endpoint | Gateway endpoint on all route tables |
| SSM VPC endpoints (optional) | Interface endpoints for ssm, ssmmessages, ec2messages |
| DNS query logging (optional) | Route53 Resolver query logs → CloudWatch Logs |
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
| `deploy_proxy_subnet` | bool | `false` | Deploy a dedicated proxy subnet for transparent egress proxy |
| `proxy_eni_id` | string | `""` | ENI ID of proxy instance. When set, app subnet routes through proxy instead of NAT |
| `deploy_ssm_endpoints` | bool | `false` | Deploy SSM VPC interface endpoints (~$22/mo per AZ) |
| `enable_dns_query_logging` | bool | `false` | Enable Route53 Resolver DNS query logging (~$0.60/million queries) |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | Map of AZ → public subnet ID |
| `app_subnet_ids` | Map of AZ → app subnet ID |
| `data_subnet_ids` | Map of AZ → data subnet ID |
| `proxy_subnet_ids` | Map of AZ → proxy subnet ID (empty if proxy disabled) |
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

### Egress proxy support

- **Dedicated proxy subnet** — avoids routing loops. Proxy subnet routes to NAT, app subnet routes to proxy.
- **`proxy_eni_id`** — when set, app subnet `0.0.0.0/0` routes to the proxy ENI instead of NAT. The proxy instance (deployed separately) intercepts and filters traffic.
- **fck-nat route management** — automatically disabled when `deploy_proxy_subnet = true`. fck-nat's service monitors route tables and would recreate routes that conflict with proxy routing.

### SSM VPC endpoints

- **3 interface endpoints** — `ssm`, `ssmmessages`, `ec2messages`. Allows SSM access without internet. Essential when using an egress proxy (SSM breaks under transparent HTTPS interception).
- **Shared security group** — allows HTTPS (443) from VPC CIDR.
- **Private DNS enabled** — instances resolve SSM endpoints to VPC-internal IPs automatically.
- **Cost** — ~$7.30/mo per endpoint per AZ ($22/mo for all 3 in 1 AZ).

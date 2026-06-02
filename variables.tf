variable "app_name" {
  type        = string
  description = "Application name, used in resource naming"
}

variable "environment" {
  type        = string
  description = "Environment name (e.g. prod, sandbox, lab)"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block (e.g. 10.0.0.0/16)"
}

variable "azs" {
  type        = list(string)
  description = "List of availability zones. Single for non-prod, multiple for prod."
}

variable "deploy_nat" {
  type        = bool
  default     = true
  description = "Deploy NAT for app subnet outbound internet. Disable if only using public subnet resources."
}

variable "use_fck_nat" {
  type        = bool
  default     = false
  description = "Use fck-nat (t4g.nano) instead of managed NAT Gateway. Ignored if deploy_nat = false."
}

variable "internal_domain" {
  type        = string
  description = "Internal domain for Route53 private hosted zone (e.g. dojo.internal)"
}

variable "deploy_proxy_subnet" {
  type        = bool
  default     = false
  description = "Deploy a dedicated proxy subnet for transparent egress proxy. Routes to fck-nat/NAT GW."
}

variable "proxy_eni_id" {
  type        = string
  default     = ""
  description = "ENI ID of the proxy instance. When set, app subnet routes 0.0.0.0/0 to this ENI instead of NAT. Requires deploy_proxy_subnet = true."
}

variable "deploy_ssm_endpoints" {
  type        = bool
  default     = false
  description = "Deploy VPC interface endpoints for SSM (ssm, ssmmessages, ec2messages). ~$22/mo per AZ."
}

variable "enable_dns_query_logging" {
  type        = bool
  default     = false
  description = "Enable Route53 Resolver DNS query logging to CloudWatch Logs. ~$0.60/million queries."
}

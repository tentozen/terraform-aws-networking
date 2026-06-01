locals {
  tenant   = "${var.app_name}-${var.environment}"
  az_index = { for i, az in var.azs : az => i }
}

# =============================================================================
# VPC
# =============================================================================

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.tenant}-vpc" }
}

# =============================================================================
# Subnets (per AZ)
# =============================================================================

resource "aws_subnet" "public" {
  for_each = local.az_index

  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, each.value)
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = { Name = "${local.tenant}-public-${each.key}" }
}

resource "aws_subnet" "app" {
  for_each = local.az_index

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 4, each.value + 1)
  availability_zone = each.key

  tags = { Name = "${local.tenant}-app-${each.key}" }
}

resource "aws_subnet" "data" {
  for_each = local.az_index

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 128)
  availability_zone = each.key

  tags = { Name = "${local.tenant}-data-${each.key}" }
}

# =============================================================================
# Internet Gateway
# =============================================================================

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.tenant}-igw" }
}

# =============================================================================
# NAT — Gateway (default) or fck-nat (cost-conscious)
# =============================================================================

# --- NAT Gateway ---

resource "aws_eip" "nat" {
  for_each = var.deploy_nat && !var.use_fck_nat ? local.az_index : {}

  domain = "vpc"

  tags = { Name = "${local.tenant}-nat-eip-${each.key}" }
}

resource "aws_nat_gateway" "main" {
  for_each = var.deploy_nat && !var.use_fck_nat ? local.az_index : {}

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  depends_on = [aws_internet_gateway.main]

  tags = { Name = "${local.tenant}-nat-${each.key}" }
}

# --- fck-nat ---

module "fck_nat" {
  for_each = var.deploy_nat && var.use_fck_nat ? local.az_index : {}

  source = "git::https://github.com/RaJiska/terraform-aws-fck-nat.git"
  name   = "${local.tenant}-nat-${each.key}"

  vpc_id        = aws_vpc.main.id
  subnet_id     = aws_subnet.public[each.key].id
  instance_type = "t4g.nano"
  ha_mode       = false

  update_route_tables = true
  route_tables_ids = {
    "app-${each.key}" = aws_route_table.app[each.key].id
  }

  depends_on = [aws_internet_gateway.main]

  tags = { Name = "${local.tenant}-nat-${each.key}" }
}

# =============================================================================
# Route Tables
# =============================================================================

# Public: shared, 0.0.0.0/0 -> IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.tenant}-rt-public" }
}

# App: per AZ, route managed by NAT Gateway or fck-nat
resource "aws_route_table" "app" {
  for_each = local.az_index

  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.tenant}-rt-app-${each.key}" }
}

# Route managed by us for NAT Gateway, by fck-nat module when use_fck_nat = true
resource "aws_route" "app_nat" {
  for_each = var.deploy_nat && !var.use_fck_nat ? local.az_index : {}

  route_table_id         = aws_route_table.app[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[each.key].id
}

# Data: shared, no default route (isolated)
resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.tenant}-rt-data" }
}

# Route table associations
resource "aws_route_table_association" "public" {
  for_each = local.az_index

  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "app" {
  for_each = local.az_index

  subnet_id      = aws_subnet.app[each.key].id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table_association" "data" {
  for_each = local.az_index

  subnet_id      = aws_subnet.data[each.key].id
  route_table_id = aws_route_table.data.id
}

# =============================================================================
# Proxy Subnet (optional — for transparent egress proxy)
# =============================================================================

resource "aws_subnet" "proxy" {
  for_each = var.deploy_proxy_subnet ? local.az_index : {}

  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 64)
  availability_zone = each.key

  tags = { Name = "${local.tenant}-proxy-${each.key}" }
}

resource "aws_route_table" "proxy" {
  count  = var.deploy_proxy_subnet ? 1 : 0
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.tenant}-rt-proxy" }
}

# Proxy subnet routes to NAT (fck-nat or NAT GW) — same as app subnet
resource "aws_route" "proxy_nat" {
  for_each = var.deploy_proxy_subnet && var.deploy_nat && !var.use_fck_nat ? { "proxy" = true } : {}

  route_table_id         = aws_route_table.proxy[0].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.main[var.azs[0]].id
}

# When using fck-nat, add the proxy route table to fck-nat's managed tables
# so fck-nat creates the route for us. We handle this by creating a separate
# fck-nat route for the proxy subnet.
resource "aws_route" "proxy_fck_nat" {
  for_each = var.deploy_proxy_subnet && var.deploy_nat && var.use_fck_nat ? { "proxy" = true } : {}

  route_table_id         = aws_route_table.proxy[0].id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = module.fck_nat[var.azs[0]].eni_id

  depends_on = [module.fck_nat]
}

resource "aws_route_table_association" "proxy" {
  for_each = var.deploy_proxy_subnet ? local.az_index : {}

  subnet_id      = aws_subnet.proxy[each.key].id
  route_table_id = aws_route_table.proxy[0].id
}

# =============================================================================
# VPC Endpoints
# =============================================================================

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.app : rt.id],
    [aws_route_table.data.id],
    var.deploy_proxy_subnet ? [aws_route_table.proxy[0].id] : [],
  )

  tags = { Name = "${local.tenant}-s3-endpoint" }
}

# =============================================================================
# Route53 Private Hosted Zone
# =============================================================================

resource "aws_route53_zone" "internal" {
  name = var.internal_domain

  vpc {
    vpc_id = aws_vpc.main.id
  }

  tags = { Name = "${local.tenant}-${var.internal_domain}" }
}

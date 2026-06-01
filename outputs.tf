output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnet_ids" {
  value = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "app_subnet_ids" {
  value = { for az, subnet in aws_subnet.app : az => subnet.id }
}

output "data_subnet_ids" {
  value = { for az, subnet in aws_subnet.data : az => subnet.id }
}

output "nat_public_ips" {
  value = var.deploy_nat && !var.use_fck_nat ? { for az, eip in aws_eip.nat : az => eip.public_ip } : {}
}

output "private_zone_id" {
  value = aws_route53_zone.internal.zone_id
}

output "internal_domain" {
  value = var.internal_domain
}

output "vpc_cidr" {
  value = var.vpc_cidr
}

output "proxy_subnet_ids" {
  value = { for az, subnet in aws_subnet.proxy : az => subnet.id }
}

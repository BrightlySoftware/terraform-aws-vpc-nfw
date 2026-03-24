output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "default_security_group_id" {
  description = "The ID of the default security group (locked down, no rules)"
  value       = aws_default_security_group.default.id
}

output "private_subnets" {
  description = "Map of private subnet IDs by name"
  value       = zipmap(aws_subnet.private[*].tags["Name"], aws_subnet.private[*].id)
}

output "private_subnets_cidr_blocks" {
  description = "Map of private subnet CIDRs by name"
  value       = zipmap(aws_subnet.private[*].tags["Name"], aws_subnet.private[*].cidr_block)
}

output "public_subnets" {
  description = "Map of public subnet IDs by name"
  value       = zipmap(aws_subnet.public[*].tags["Name"], aws_subnet.public[*].id)
}

output "public_subnets_cidr_blocks" {
  description = "Map of public subnet CIDRs by name"
  value       = zipmap(aws_subnet.public[*].tags["Name"], aws_subnet.public[*].cidr_block)
}

output "public_route_table_ids" {
  description = "List of IDs of public route tables"
  value       = aws_route_table.public[*].id
}

output "private_route_table_ids" {
  description = "List of IDs of private route tables"
  value       = aws_route_table.private[*].id
}

output "nat_ids" {
  description = "List of allocation ID of Elastic IPs created for AWS NAT Gateway"
  value       = aws_eip.nat[*].id
}

output "nat_public_ips" {
  description = "List of public Elastic IPs created for AWS NAT Gateway"
  value       = aws_eip.nat[*].public_ip
}

output "natgw_ids" {
  description = "List of NAT Gateway IDs"
  value       = aws_nat_gateway.this[*].id
}

output "igw_id" {
  description = "The ID of the Internet Gateway"
  value       = local.has_public_subnets ? aws_internet_gateway.this[0].id : null
}

output "tgw_attachment_id" {
  description = "ID of the Transit Gateway VPC attachment (null if no TGW configured)"
  value       = var.tgw_id != null ? aws_ec2_transit_gateway_vpc_attachment.this[0].id : null
}

output "flow_log_s3_bucket_arn" {
  description = "ARN of the S3 bucket storing VPC flow logs"
  value       = aws_s3_bucket.flowlogs.arn
}

output "flow_log_s3_bucket_name" {
  description = "Name of the S3 bucket storing VPC flow logs"
  value       = aws_s3_bucket.flowlogs.id
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for VPC log encryption"
  value       = aws_kms_key.vpc_logs.arn
}

output "kms_key_alias" {
  description = "Alias of the KMS key used for VPC log encryption"
  value       = aws_kms_alias.vpc_logs.name
}

output "vpc_endpoints" {
  description = "Map of VPC endpoint IDs"
  value       = var.create_vpc_endpoints ? module.vpc_endpoints.vpc_endpoint_ids : {}
}

output "vpc_endpoint_security_groups" {
  description = "Map of security group IDs created for VPC endpoints"
  value       = var.create_vpc_endpoints ? module.vpc_endpoints.security_groups : {}
}

output "subnets" {
  description = "Map of all subnet IDs and CIDRs by name"
  value = {
    for subnet in concat(
      aws_subnet.public[*],
      aws_subnet.private[*]
      ) : subnet.tags["Name"] => {
      id                = subnet.id
      arn               = subnet.arn
      cidr              = subnet.cidr_block
      availability_zone = subnet.availability_zone
    }
  }
}

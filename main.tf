data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

######
# VPC
######
resource "aws_vpc" "this" {
  cidr_block           = var.cidr
  instance_tenancy     = var.instance_tenancy
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = var.vpc_name
  })
}

# Lock down default security group — SC-7(5) deny by default
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-default-sg-restricted"
  })
}

###################
# Internet Gateway (conditional: only when public subnets exist)
###################
resource "aws_internet_gateway" "this" {
  count = local.has_public_subnets ? 1 : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-igw"
  })
}

###################
# VPC Endpoints
###################
module "vpc_endpoints" {
  source = "./modules/vpc-endpoint"

  create_vpc_endpoints                = var.create_vpc_endpoints
  associate_with_private_route_tables = var.associate_with_private_route_tables
  associate_with_public_route_tables  = var.associate_with_public_route_tables
  vpc_id                              = aws_vpc.this.id

  subnet_ids = length(aws_subnet.private) > 0 ? [for subnet in aws_subnet.private : subnet.id] : null

  private_route_table_ids = [for rt in aws_route_table.private : rt.id]
  route_table_ids         = [for rt in aws_route_table.private : rt.id]
  public_route_table_ids  = [for rt in aws_route_table.public : rt.id]

  vpc_endpoints                = var.vpc_endpoints
  vpc_endpoint_security_groups = var.vpc_endpoint_security_groups

  tags = var.tags
}

##############
# NAT Gateway
##############
resource "aws_eip" "nat" {
  count = local.create_nat_gateways ? local.nat_gateway_count : 0

  domain = "vpc"

  tags = merge(var.tags, {
    Name = format("%s-%s", var.resource_prefix, element(var.azs, count.index))
  })
}

resource "aws_nat_gateway" "this" {
  count = local.create_nat_gateways ? local.nat_gateway_count : 0

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = element(aws_subnet.public[*].id, count.index)

  tags = merge(var.tags, {
    Name = format("%s-nat-%s", var.resource_prefix, element(var.azs, count.index))
  })

  depends_on = [aws_internet_gateway.this, aws_subnet.public]
}

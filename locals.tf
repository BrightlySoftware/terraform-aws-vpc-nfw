locals {
  public_subnets  = [for s in var.subnets : s if s.type == "public"]
  private_subnets = [for s in var.subnets : s if s.type == "private"]

  has_public_subnets = length(local.public_subnets) > 0

  # If 0.0.0.0/0 is in tgw_routes, all traffic routes through TGW — skip NAT GW creation
  tgw_is_default_route = contains(var.tgw_routes, "0.0.0.0/0")

  # NAT GWs needed only when public subnets exist AND TGW is not the default route
  create_nat_gateways = local.has_public_subnets && !local.tgw_is_default_route

  nat_gateway_count = local.create_nat_gateways ? (var.one_nat_gateway_per_az ? length(var.azs) : length(local.private_subnets)) : 0

  vpc_id = aws_vpc.this.id
}

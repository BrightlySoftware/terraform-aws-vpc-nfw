################
# Public routes
################
resource "aws_route_table" "public" {
  count = local.has_public_subnets ? length(local.public_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, {
    Name = format("%s-public-%s-rtb", var.resource_prefix, element(var.azs, count.index))
  })
}

resource "aws_route" "public_internet_gateway" {
  count = local.has_public_subnets ? length(local.public_subnets) : 0

  route_table_id         = aws_route_table.public[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this[0].id

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "public_custom" {
  count = length(var.public_custom_routes) > 0 ? length(var.public_custom_routes) * length(aws_route_table.public) : 0

  route_table_id = aws_route_table.public[count.index % length(aws_route_table.public)].id

  destination_cidr_block     = var.public_custom_routes[floor(count.index / length(aws_route_table.public))].destination_cidr_block
  destination_prefix_list_id = var.public_custom_routes[floor(count.index / length(aws_route_table.public))].destination_prefix_list_id
  network_interface_id       = var.public_custom_routes[floor(count.index / length(aws_route_table.public))].network_interface_id
  gateway_id                 = try(var.public_custom_routes[floor(count.index / length(aws_route_table.public))].internet_route, false) ? aws_internet_gateway.this[0].id : null
  transit_gateway_id         = var.public_custom_routes[floor(count.index / length(aws_route_table.public))].transit_gateway_id

  timeouts {
    create = "5m"
  }
}

#################
# Private routes
#################
resource "aws_route_table" "private" {
  count = length(local.private_subnets) > 0 ? length(local.private_subnets) : 0

  vpc_id = local.vpc_id

  tags = merge(var.tags, {
    Name = format("%s-private-%s-rtb", var.resource_prefix, element(var.azs, count.index))
  })
}

resource "aws_route" "private_nat_gateway" {
  count = local.create_nat_gateways ? local.nat_gateway_count : 0

  route_table_id         = element(aws_route_table.private[*].id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = element(aws_nat_gateway.this[*].id, count.index)

  timeouts {
    create = "5m"
  }
}

resource "aws_route" "private_custom" {
  count = length(var.private_custom_routes) > 0 ? length(var.private_custom_routes) * length(aws_route_table.private) : 0

  route_table_id = aws_route_table.private[count.index % length(aws_route_table.private)].id

  destination_cidr_block     = var.private_custom_routes[floor(count.index / length(aws_route_table.private))].destination_cidr_block
  destination_prefix_list_id = var.private_custom_routes[floor(count.index / length(aws_route_table.private))].destination_prefix_list_id
  network_interface_id       = var.private_custom_routes[floor(count.index / length(aws_route_table.private))].network_interface_id
  transit_gateway_id         = var.private_custom_routes[floor(count.index / length(aws_route_table.private))].transit_gateway_id
  vpc_endpoint_id            = var.private_custom_routes[floor(count.index / length(aws_route_table.private))].vpc_endpoint_id

  timeouts {
    create = "5m"
  }
}

##########################
# Route table association
##########################
resource "aws_route_table_association" "private" {
  count = length(local.private_subnets)

  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = element(aws_route_table.private[*].id, count.index)
}

resource "aws_route_table_association" "public" {
  count = length(local.public_subnets)

  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = element(aws_route_table.public[*].id, count.index)
}

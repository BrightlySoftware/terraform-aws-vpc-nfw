# -----------------------------------------------------------------------------
# Transit Gateway Integration
#
# All resources are conditional on var.tgw_id being provided.
# The TGW attachment includes all private subnets.
# Routes in tgw_routes are added to every private route table.
# When 0.0.0.0/0 is in tgw_routes (ROSA pattern), NAT GWs are skipped and
# the default route in private RTs points to the TGW.
# -----------------------------------------------------------------------------

resource "aws_ec2_transit_gateway_vpc_attachment" "this" {
  count = var.tgw_id != null ? 1 : 0

  transit_gateway_id = var.tgw_id
  vpc_id             = local.vpc_id
  subnet_ids         = aws_subnet.private[*].id

  tags = merge(var.tags, {
    Name = "${var.resource_prefix}-tgw-attachment"
  })
}

# TGW routes in private route tables (excluding 0.0.0.0/0 which is handled below)
resource "aws_route" "tgw" {
  count = var.tgw_id != null ? length([
    for pair in setproduct(range(length(aws_route_table.private)), [
      for r in var.tgw_routes : r if r != "0.0.0.0/0"
    ]) : pair
  ]) : 0

  route_table_id = aws_route_table.private[
    element(
      [for pair in setproduct(range(length(aws_route_table.private)), [
        for r in var.tgw_routes : r if r != "0.0.0.0/0"
      ]) : pair],
      count.index
    )[0]
  ].id

  destination_cidr_block = element(
    [for pair in setproduct(range(length(aws_route_table.private)), [
      for r in var.tgw_routes : r if r != "0.0.0.0/0"
    ]) : pair],
    count.index
  )[1]

  transit_gateway_id = var.tgw_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

# Default route (0.0.0.0/0) via TGW — ROSA pattern
# Only created when 0.0.0.0/0 is in tgw_routes AND no NAT GW default routes exist
resource "aws_route" "tgw_default" {
  count = local.tgw_is_default_route && var.tgw_id != null ? length(aws_route_table.private) : 0

  route_table_id         = aws_route_table.private[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  transit_gateway_id     = var.tgw_id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.this]
}

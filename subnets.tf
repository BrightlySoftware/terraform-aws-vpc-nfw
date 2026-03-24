##################
# Public subnets #
##################
resource "aws_subnet" "public" {
  count = length(local.public_subnets)

  vpc_id                  = local.vpc_id
  cidr_block              = local.public_subnets[count.index].cidr
  availability_zone       = local.public_subnets[count.index].availability_zone
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = (
      local.public_subnets[count.index].custom_name != null ?
      local.public_subnets[count.index].custom_name :
      format("%s-public-%s", var.resource_prefix, local.public_subnets[count.index].availability_zone)
    )
    Type = "public"
  })
}

##################
# Private subnet #
##################
resource "aws_subnet" "private" {
  count = length(local.private_subnets)

  vpc_id            = local.vpc_id
  cidr_block        = local.private_subnets[count.index].cidr
  availability_zone = local.private_subnets[count.index].availability_zone

  tags = merge(var.tags, {
    Name = (
      local.private_subnets[count.index].custom_name != null ?
      local.private_subnets[count.index].custom_name :
      format("%s-private-%s", var.resource_prefix, local.private_subnets[count.index].availability_zone)
    )
    Type = "private"
  })
}

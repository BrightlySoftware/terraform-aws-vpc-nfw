# Standard VPC — Public + Private Subnets with Transit Gateway
#
# This example creates a VPC with public and private subnets across two AZs.
# Private subnets have internet access via NAT Gateways.
# Specific CIDRs are routed through an existing Transit Gateway.

provider "aws" {
  region = "us-gov-west-1"
}

module "vpc" {
  source = "../../"

  vpc_name        = "prod-vpc"
  resource_prefix = "prod"
  cidr            = "10.0.0.0/16"
  azs             = ["us-gov-west-1a", "us-gov-west-1b"]

  subnets = [
    { cidr = "10.0.1.0/24", type = "public", availability_zone = "us-gov-west-1a" },
    { cidr = "10.0.2.0/24", type = "public", availability_zone = "us-gov-west-1b" },
    { cidr = "10.0.10.0/24", type = "private", availability_zone = "us-gov-west-1a" },
    { cidr = "10.0.11.0/24", type = "private", availability_zone = "us-gov-west-1b" },
  ]

  # Route on-prem networks through Transit Gateway
  tgw_id     = "tgw-0123456789abcdef0"
  tgw_routes = ["10.100.0.0/16", "10.200.0.0/16"]

  tags = {
    Environment = "production"
    Compliance  = "FedRAMP-Moderate"
    Project     = "my-project"
    ManagedBy   = "terraform"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "flow_log_bucket" {
  value = module.vpc.flow_log_s3_bucket_name
}

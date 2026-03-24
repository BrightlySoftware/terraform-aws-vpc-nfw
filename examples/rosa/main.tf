# ROSA Privatelink Cluster — Private-Only Subnets, All Traffic via TGW
#
# This example creates a VPC with only private subnets for a ROSA privatelink
# cluster. All egress traffic (0.0.0.0/0) is routed through the Transit Gateway,
# where it exits to the internet via a centralized egress VPC.
#
# No Internet Gateway or NAT Gateways are created.

provider "aws" {
  region = "us-gov-west-1"
}

module "vpc" {
  source = "../../"

  vpc_name        = "rosa-cluster-vpc"
  resource_prefix = "rosa-cluster"
  cidr            = "10.1.0.0/16"
  azs             = ["us-gov-west-1a", "us-gov-west-1b", "us-gov-west-1c"]

  subnets = [
    { cidr = "10.1.1.0/24", type = "private", availability_zone = "us-gov-west-1a" },
    { cidr = "10.1.2.0/24", type = "private", availability_zone = "us-gov-west-1b" },
    { cidr = "10.1.3.0/24", type = "private", availability_zone = "us-gov-west-1c" },
  ]

  # Route ALL traffic through TGW — egress handled by centralized VPC
  tgw_id     = "tgw-0123456789abcdef0"
  tgw_routes = ["0.0.0.0/0"]

  tags = {
    Environment = "production"
    Compliance  = "FedRAMP-Moderate"
    Project     = "rosa"
    ManagedBy   = "terraform"
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnet_ids" {
  value = module.vpc.private_subnets
}

output "tgw_attachment_id" {
  value = module.vpc.tgw_attachment_id
}

output "flow_log_bucket" {
  value = module.vpc.flow_log_s3_bucket_name
}

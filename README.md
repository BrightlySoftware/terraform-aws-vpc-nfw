# terraform-aws-vpc-nfw

Terraform module for provisioning a FedRAMP Moderate compliant VPC in AWS GovCloud.

Forked from [Coalfire-CF/terraform-aws-vpc-nfw](https://github.com/Coalfire-CF/terraform-aws-vpc-nfw) and customized for BrightlySoftware.

## Features

- **VPC with public and/or private subnets** across multiple availability zones
- **NAT Gateways** with Elastic IPs for private subnet internet egress (per AZ)
- **Transit Gateway integration** — pass TGW ID + route CIDRs, attachment created automatically
- **ROSA (private-only) support** — route all traffic via TGW, no public subnets needed
- **Default Security Group lockdown** — all rules removed (SC-7(5) deny-by-default)
- **VPC Endpoints** — flexible endpoint configuration via submodule

### FedRAMP Logging & Encryption

| Control | Implementation |
|---------|---------------|
| AU-2, AU-3 (Audit Events & Content) | VPC Flow Logs — ALL traffic, v5 extended format, hourly partitioned |
| AU-9 (Audit Protection) | S3 bucket versioning, KMS encryption, public access blocked, HTTPS enforced |
| AU-11 (Audit Retention) | S3 lifecycle: Standard → Glacier → delete (configurable) |
| SC-7 (Boundary Protection) | VPC Flow Logs capture all boundary traffic |
| SC-7(5) (Deny by Default) | Default security group locked down |
| SC-12, SC-13 (Crypto) | Customer-managed KMS key with automatic rotation |

## Usage

### Standard VPC (public + private subnets)

```hcl
module "vpc" {
  source = "github.com/BrightlySoftware/terraform-aws-vpc-nfw"

  vpc_name        = "prod-vpc"
  resource_prefix = "prod"
  cidr            = "10.0.0.0/16"
  azs             = ["us-gov-west-1a", "us-gov-west-1b"]

  subnets = [
    { cidr = "10.0.1.0/24",  type = "public",  availability_zone = "us-gov-west-1a" },
    { cidr = "10.0.2.0/24",  type = "public",  availability_zone = "us-gov-west-1b" },
    { cidr = "10.0.10.0/24", type = "private", availability_zone = "us-gov-west-1a" },
    { cidr = "10.0.11.0/24", type = "private", availability_zone = "us-gov-west-1b" },
  ]

  tgw_id     = "tgw-0123456789abcdef0"
  tgw_routes = ["10.100.0.0/16", "10.200.0.0/16"]

  tags = {
    Environment = "production"
    Compliance  = "FedRAMP-Moderate"
  }
}
```

### ROSA Privatelink Cluster (private-only, all traffic via TGW)

```hcl
module "vpc" {
  source = "github.com/BrightlySoftware/terraform-aws-vpc-nfw"

  vpc_name        = "rosa-cluster-vpc"
  resource_prefix = "rosa-cluster"
  cidr            = "10.1.0.0/16"
  azs             = ["us-gov-west-1a", "us-gov-west-1b", "us-gov-west-1c"]

  subnets = [
    { cidr = "10.1.1.0/24", type = "private", availability_zone = "us-gov-west-1a" },
    { cidr = "10.1.2.0/24", type = "private", availability_zone = "us-gov-west-1b" },
    { cidr = "10.1.3.0/24", type = "private", availability_zone = "us-gov-west-1c" },
  ]

  tgw_id     = "tgw-0123456789abcdef0"
  tgw_routes = ["0.0.0.0/0"]

  tags = {
    Environment = "production"
    Compliance  = "FedRAMP-Moderate"
  }
}
```

## Routing Logic

| Scenario | IGW | NAT GW | Default Route (Private) |
|----------|-----|--------|------------------------|
| Public + private subnets, specific TGW routes | ✅ | ✅ (per AZ) | NAT GW (TGW for specific CIDRs) |
| Public + private subnets, no TGW | ✅ | ✅ (per AZ) | NAT GW |
| Private-only subnets, `0.0.0.0/0` via TGW | ❌ | ❌ | TGW |
| Public + private, `0.0.0.0/0` via TGW | ✅ | ❌ | TGW |

## Requirements

| Name | Version |
|------|---------|
| Terraform | >= 1.5 |
| AWS Provider | >= 5.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `vpc_name` | Name for the VPC | `string` | — | yes |
| `resource_prefix` | Prefix for all resource names | `string` | — | yes |
| `cidr` | CIDR block for the VPC | `string` | — | yes |
| `azs` | List of availability zones | `list(string)` | `[]` | no |
| `subnets` | List of `{cidr, type, availability_zone}` configs | `list(object)` | — | yes |
| `tags` | Tags applied to all resources | `map(string)` | `{}` | no |
| `instance_tenancy` | VPC instance tenancy | `string` | `"default"` | no |
| `one_nat_gateway_per_az` | One NAT GW per AZ | `bool` | `true` | no |
| `tgw_id` | Existing Transit Gateway ID | `string` | `null` | no |
| `tgw_routes` | CIDRs to route via TGW in private subnets | `list(string)` | `[]` | no |
| `public_custom_routes` | Custom routes for public subnets | `list(object)` | `[]` | no |
| `private_custom_routes` | Custom routes for private subnets | `list(object)` | `[]` | no |
| `create_vpc_endpoints` | Enable VPC endpoints | `bool` | `false` | no |
| `vpc_endpoints` | VPC endpoint definitions | `map(object)` | `{}` | no |
| `vpc_endpoint_security_groups` | Security groups for VPC endpoints | `map(object)` | `{}` | no |
| `flow_log_retention_days` | Days in S3 Standard before Glacier | `number` | `365` | no |
| `flow_log_archive_retention_days` | Days in Glacier (total = retention + archive) | `number` | `730` | no |
| `flow_log_max_aggregation_interval` | Flow log capture interval (60 or 600 seconds) | `number` | `600` | no |

## Outputs

| Name | Description |
|------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr_block` | VPC CIDR block |
| `default_security_group_id` | Default SG ID (locked down) |
| `public_subnets` | Map of public subnet IDs by name |
| `private_subnets` | Map of private subnet IDs by name |
| `public_route_table_ids` | Public route table IDs |
| `private_route_table_ids` | Private route table IDs |
| `natgw_ids` | NAT Gateway IDs |
| `igw_id` | Internet Gateway ID |
| `tgw_attachment_id` | Transit Gateway attachment ID |
| `flow_log_s3_bucket_arn` | S3 log bucket ARN |
| `flow_log_s3_bucket_name` | S3 log bucket name |
| `kms_key_arn` | KMS key ARN for log encryption |
| `kms_key_alias` | KMS key alias |
| `vpc_endpoints` | VPC endpoint IDs |
| `subnets` | All subnets by name with ID, ARN, CIDR, AZ |

## Changes from Coalfire Upstream

**Removed:**
- Network Firewall (entire submodule)
- Service-specific subnets (database, redshift, elasticache, intra, TGW, firewall)
- EKS/Karpenter subnet tagging
- VPN Gateway
- DNSSEC configuration
- Default VPC management
- Secondary CIDR blocks, IPv6
- DHCP options
- CloudWatch flow log option

**Added:**
- Transit Gateway attachment + automatic route integration
- ROSA pattern (auto-detected when `0.0.0.0/0` in `tgw_routes`)
- Customer-managed KMS key with alias and auto-rotation
- S3 lifecycle policies (Standard → Glacier → delete)
- S3 bucket versioning
- Deny-insecure-transport bucket policy
- VPC Flow Logs with v5 format and hourly partitioning

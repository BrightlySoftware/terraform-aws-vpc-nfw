######
# VPC
######
variable "vpc_name" {
  description = "Name to assign to the AWS VPC"
  type        = string
}

variable "resource_prefix" {
  description = "Prefix added to resource names as identifier"
  type        = string
}

variable "cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "instance_tenancy" {
  description = "A tenancy option for instances launched into the VPC"
  type        = string
  default     = "default"
}

variable "azs" {
  description = "A list of availability zones in the region"
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "List of subnet configurations. Each subnet requires a CIDR, type (public or private), and availability zone."
  type = list(object({
    custom_name       = optional(string)
    cidr              = string
    type              = string
    availability_zone = string
  }))

  validation {
    condition     = alltrue([for s in var.subnets : contains(["public", "private"], s.type)])
    error_message = "Each subnet type must be 'public' or 'private'."
  }

  validation {
    condition     = length(var.subnets) > 0
    error_message = "At least one subnet must be defined."
  }
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}

#####################
# NAT Gateway
#####################
variable "one_nat_gateway_per_az" {
  description = "Should be true if you want only one NAT Gateway per availability zone"
  type        = bool
  default     = true
}

#####################
# Transit Gateway
#####################
variable "tgw_id" {
  description = "ID of an existing Transit Gateway (optional). Required if tgw_routes is non-empty."
  type        = string
  default     = null
}

variable "tgw_routes" {
  description = "List of CIDR blocks to route through the Transit Gateway in private subnets. Use [\"0.0.0.0/0\"] to route all traffic via TGW (ROSA pattern)."
  type        = list(string)
  default     = []
}

#####################
# Custom Routes
#####################
variable "public_custom_routes" {
  description = "Custom routes for Public Subnets"
  type = list(object({
    destination_cidr_block     = optional(string, null)
    destination_prefix_list_id = optional(string, null)
    network_interface_id       = optional(string, null)
    internet_route             = optional(bool, null)
    transit_gateway_id         = optional(string, null)
  }))
  default = []
}

variable "private_custom_routes" {
  description = "Custom routes for Private Subnets"
  type = list(object({
    destination_cidr_block     = optional(string, null)
    destination_prefix_list_id = optional(string, null)
    network_interface_id       = optional(string, null)
    transit_gateway_id         = optional(string, null)
    vpc_endpoint_id            = optional(string, null)
  }))
  default = []
}

#####################
# VPC Endpoints
#####################
variable "create_vpc_endpoints" {
  description = "Whether to create VPC endpoints"
  type        = bool
  default     = false
}

variable "associate_with_private_route_tables" {
  description = "Whether to associate Gateway endpoints with private route tables"
  type        = bool
  default     = true
}

variable "associate_with_public_route_tables" {
  description = "Whether to associate Gateway endpoints with public route tables"
  type        = bool
  default     = false
}

variable "vpc_endpoints" {
  description = "Map of VPC endpoint definitions to create"
  type = map(object({
    service_name        = optional(string)
    service_type        = string
    private_dns_enabled = optional(bool, true)
    auto_accept         = optional(bool, false)
    policy              = optional(string)
    security_group_ids  = optional(list(string), [])
    tags                = optional(map(string), {})
    subnet_ids          = optional(list(string))
    ip_address_type     = optional(string)
  }))
  default = {}
}

variable "vpc_endpoint_security_groups" {
  description = "Map of security groups to create for VPC endpoints"
  type = map(object({
    name        = string
    description = optional(string, "Security group for VPC endpoint")
    ingress_rules = optional(list(object({
      description      = optional(string)
      from_port        = number
      to_port          = number
      protocol         = string
      cidr_blocks      = optional(list(string), [])
      ipv6_cidr_blocks = optional(list(string), [])
      security_groups  = optional(list(string), [])
      self             = optional(bool, false)
    })), [])
    egress_rules = optional(list(object({
      description      = optional(string)
      from_port        = number
      to_port          = number
      protocol         = string
      cidr_blocks      = optional(list(string), [])
      ipv6_cidr_blocks = optional(list(string), [])
      security_groups  = optional(list(string), [])
      self             = optional(bool, false)
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

#####################
# Flow Logs
#####################
variable "flow_log_retention_days" {
  description = "Number of days to retain VPC flow logs in S3 Standard before transitioning to Glacier"
  type        = number
  default     = 365

  validation {
    condition     = var.flow_log_retention_days >= 1
    error_message = "Flow log retention must be at least 1 day."
  }
}

variable "flow_log_archive_retention_days" {
  description = "Number of days to retain VPC flow logs in S3 Glacier after Standard retention. Total retention = retention + archive."
  type        = number
  default     = 730

  validation {
    condition     = var.flow_log_archive_retention_days >= 0
    error_message = "Flow log archive retention must be 0 or more days."
  }
}

variable "flow_log_max_aggregation_interval" {
  description = "Maximum interval in seconds during which a flow of packets is captured into a flow log record"
  type        = number
  default     = 600

  validation {
    condition     = contains([60, 600], var.flow_log_max_aggregation_interval)
    error_message = "Flow log aggregation interval must be 60 or 600 seconds."
  }
}

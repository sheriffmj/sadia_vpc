variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "availability_zone_count" {
  description = "The number of availability zones to use"
  type        = number

  # Subnet offsets are sized for 6 AZs (local.max_azs). A 7th AZ would
  # push the public subnets into the DB range.
  validation {
    condition = (
      var.availability_zone_count >= 1 &&
      var.availability_zone_count <= 6 &&
      floor(var.availability_zone_count) == var.availability_zone_count
    )
    error_message = "availability_zone_count must be a whole number from 1 to 6."
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string

  # The subnet layout (public and DB /24s, private /20s) assumes a /16.
  # A smaller VPC would make the tiers overlap
  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "vpc_cidr must be a valid IPv4 /16 CIDR block, for example 10.0.0.0/16."
  }
}

variable "interface_endpoints_services" {
  description = "The list of interface services endpoints names"
  type        = list(string)
  default = [
    "ssm",
    "ec2messages",
    "ssmmessages",
    "ec2",
    "eks",
    "ecr.api",
    "ecr.dkr",
    "sts",
    "logs"
  ]
}

variable "endpoint_client_security_group_ids" {
  description = "A map of client security group IDs for self-managed SGs that need access to the VPC interface endpoints"
  type        = map(string)
  default     = {}
}


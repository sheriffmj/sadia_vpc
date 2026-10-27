variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "sadia"

  validation {
    condition     = length(var.project_name) > 0
    error_message = "The project name must not be empty"
  }
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^([a-z]{2}-[a-z]+-[1-9])$", var.aws_region))
    error_message = "The AWS region must be a valid region code"
  }

}

variable "availability_zone_count" {
  description = "The number of availability zones to use"
  type        = number
  default     = 3

  validation {
    condition     = var.availability_zone_count > 0
    error_message = "The number of availability zones must be greater than 0"
  }
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr)) && can(regex("/16$", var.vpc_cidr))
    error_message = "The VPC CIDR block must be a valid CIDR"
  }
}

variable "inbound_web_cidr" {
  description = "The CIDR block to allow inbound HTTP and HTTPS access from"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = alltrue([for cidr in var.inbound_web_cidr : can(cidrnetmask(cidr))])
    error_message = "All inbound web CIDR blocks must be valid CIDRs"
  }
}


variable "allowed_app_sg_id" {
  description = "Optional security group ID of the allowed application"
  type        = string
  default     = null
  validation {
    condition     = var.allowed_app_sg_id == null || can(regex("^sg-[0-9a-fA-F]+$", var.allowed_app_sg_id))
    error_message = "The allowed application security group ID must be a valid security group ID"
  }
}

variable "environment" {
  description = "The environment for the deployment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of 'dev', 'staging', or 'prod'"
  }
}

variable "owner" {
  description = "The owner of the resources"
  type        = string
  default     = "SMJ"

  validation {
    condition     = length(var.owner) > 0
    error_message = "The owner must not be empty"
  }
}

variable "ssm_services" {
  description = "The list of SSM services endpoints names"
  type        = list(string)
  default = [
    "ssm",
    "ec2messages",
    "ssmmessages"
  ]
}

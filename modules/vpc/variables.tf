variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "availability_zone_count" {
  description = "The number of availability zones to use"
  type        = number
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
}

variable "inbound_web_cidr" {
  description = "The CIDR block to allow inbound HTTP and HTTPS access from"
  type        = list(string)
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


variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
  
}

variable "subnet_count" {
  description = "The number of subnets to create"
  type        = number
  default     = 3
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "open_cidr" {
  description = "The CIDR block for open access"
  type        = string
  default     = "0.0.0.0/0"
}

variable "allow_ssh_cidr" {
  description = "The CIDR block to allow SSH access from"
  type        = string
  default     = "10.255.255.1/32"
}
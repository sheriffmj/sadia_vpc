variable "project_name" {
  description = "The name of the project"
  type        = string
  default     = "sadia"
}

variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "us-east-1"
}

variable "availability_zone_count" {
  description = "The number of availability zones to use"
  type        = number
  default     = 3
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "inbound_web_cidr" {
  description = "The CIDR block to allow inbound HTTP and HTTPS access from"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}


variable "environment" {
  description = "The environment for the deployment"
  type        = string
  default     = "dev"

}

variable "owner" {
  description = "The owner of the resources"
  type        = string
  default     = "SMJ"
}

variable "ssm_services" {
  description = "The list of SSM services endpoints names"
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

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.36"
}

variable "instance_type" {
  description = "The instance type for the EKS node group"
  type        = string
  default     = "t3.medium"
}

variable "admin_cidrs" {
  description = "The list of CIDR blocks allowed to access the EKS cluster endpoint"
  type        = list(string)
  default     = []
  sensitive   = true
}

variable "admin_principal_arn" {
  description = "The ARN of the admin principal for the EKS cluster"
  type        = string
}
variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
}

variable "environment" {
  description = "The environment for the deployment (e.g., dev, staging, prod)"
  type        = string
}

variable "owner" {
  description = "The owner of the resources"
  type        = string
}

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

variable "admin_cidrs" {
  description = "The list of CIDR blocks allowed to access the admin interface"
  type        = list(string)
}

variable "admin_principal_arn" {
  description = "The ARN of the admin principal"
  type        = string
}

variable "retention_in_days" {
  description = "The number of days to retain logs"
  type        = number
}

variable "enabled_cluster_log_types" {
  description = "The list of enabled cluster log types"
  type        = list(string)
}

variable "nodes_ami_type" {
  description = "The AMI type for the nodes"
  type        = string
}

variable "kubernetes_version" {
  description = "The version of Kubernetes to deploy"
  type        = string
}

variable "node_groups" {
  description = "The configuration for the EKS node groups"
  type        = map(object({
    desired_size = number
    max_size     = number
    min_size     = number
    instance_type = string
  }))
}

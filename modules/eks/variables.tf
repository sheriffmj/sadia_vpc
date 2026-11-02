variable "admin_cidrs" {
  description = "The list of CIDR blocks allowed to access the EKS cluster endpoint"
  type        = list(string)
  default     = []
}

variable "admin_principal_arn" {
  description = "The ARN of the admin principal for the EKS cluster"
  type        = string
  default = null
}

variable "project_name" {
  description = "The name of the project"
  type        = string
}

variable "kubernetes_version" {
  description = "The Kubernetes version for the EKS cluster"
  type        = string
}

variable "instance_type" {
  description = "The instance type for the EKS node group"
  type        = string
  default     = "t3.medium"
}

variable "endpoints_security_group_id" {
  description = "The security group ID for the VPC endpoints that the EKS cluster must reach"
  type        = string
}

variable "private_subnet_ids" {
  description = "The list of private subnet IDs for the EKS cluster"
  type        = list(string)
  default     = []
}

variable "desired_size" {
  description = "The desired number of nodes in the EKS node group"
  type        = number
}

variable "max_size" {
  description = "The maximum number of nodes in the EKS node group"
  type        = number
}

variable "min_size" {
  description = "The minimum number of nodes in the EKS node group"
  type        = number

}

variable "retention_in_days" {
  description = "The retention period for CloudWatch logs"
  type        = number
  default     = 90
}

variable "enabled_cluster_log_types" {
  description = "The types of cluster logs to enable"
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "nodes_ami_type" {
  description = "The AMI type for the EKS nodes"
  type        = string
  default     = "AL2023_x86_64_STANDARD"
}

variable "auth_mode" {
  description = "The authentication mode for the EKS cluster"
  type        = string
  default     = "API_AND_CONFIG_MAP"
}
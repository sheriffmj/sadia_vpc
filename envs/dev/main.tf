module "vpc" {
  project_name = var.project_name
  source       = "../../modules/vpc"

  availability_zone_count            = var.availability_zone_count
  vpc_cidr                           = var.vpc_cidr
  inbound_web_cidr                   = var.inbound_web_cidr
  endpoint_client_security_group_ids = {}
}

module "eks" {
  source = "../../modules/eks"

  project_name                = var.project_name
  private_subnet_ids          = module.vpc.private_subnet_ids
  endpoints_security_group_id = module.vpc.endpoints_sg_id
  admin_cidrs                 = var.admin_cidrs
  admin_principal_arn         = var.admin_principal_arn
  kubernetes_version          = var.kubernetes_version
  node_groups                 = var.node_groups
  retention_in_days           = var.retention_in_days
  enabled_cluster_log_types   = var.enabled_cluster_log_types
  nodes_ami_type              = var.nodes_ami_type

  depends_on = [module.vpc]
}

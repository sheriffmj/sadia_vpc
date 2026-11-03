resource "aws_vpc_security_group_ingress_rule" "endpoints_from_cluster" {
  security_group_id            = var.endpoints_security_group_id
  referenced_security_group_id = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  description                  = "HTTPS from EKS cluster SG to VPC endpoints"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode                         = var.auth_mode
    bootstrap_cluster_creator_admin_permissions = false
  }

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = length(var.admin_cidrs) > 0
    public_access_cidrs     = length(var.admin_cidrs) > 0 ? var.admin_cidrs : null
  }
  enabled_cluster_log_types = var.enabled_cluster_log_types

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy, aws_cloudwatch_log_group.eks_cluster_logs]

  tags = {
    Name = "${var.project_name}-eks-cluster"
  }
}

resource "aws_eks_node_group" "eks_node_group" {
  for_each = var.node_groups
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.project_name}-eks-node-group-${each.key}"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  instance_types  = [each.value.instance_type]
  ami_type        = var.nodes_ami_type


  subnet_ids = var.private_subnet_ids
  scaling_config {
    desired_size = each.value.desired_size
    max_size     = each.value.max_size
    min_size     = each.value.min_size
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]


  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_nodegroup_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_cni_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_ecr_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_ssm_attach,
    aws_vpc_security_group_ingress_rule.endpoints_from_cluster,
  ]

}

resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.project_name}-eks-cluster/cluster"
  retention_in_days = var.retention_in_days

  tags = {
    Name = "${var.project_name}-eks-cluster-logs"
  }
}




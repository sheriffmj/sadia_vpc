resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  vpc_config {
    subnet_ids              = [for subnet in aws_subnet.private_subnets : subnet.id]
    endpoint_private_access = true
    endpoint_public_access  = length(var.admin_cidrs) > 0
    public_access_cidrs     = length(var.admin_cidrs) > 0 ? var.admin_cidrs : null
  }
  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy, aws_cloudwatch_log_group.eks_cluster_logs]

  tags = {
    Name = "${var.project_name}-eks-cluster"
  }
}

resource "aws_eks_node_group" "eks_node_group" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.project_name}-eks-node-group"
  node_role_arn   = aws_iam_role.eks_nodegroup.arn
  instance_types  = [var.instance_type]
  ami_type        = "AL2023_x86_64_STANDARD"


  subnet_ids = [for subnet in aws_subnet.private_subnets : subnet.id]
  scaling_config {
    desired_size = 2
    max_size     = 3
    min_size     = 1
  }
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]


  }
  depends_on = [
    aws_iam_role_policy_attachment.eks_nodegroup_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_cni_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_ecr_attach,
    aws_iam_role_policy_attachment.eks_nodegroup_ssm_attach,
    aws_vpc_endpoint.s3_gateway,
    aws_vpc_endpoint.ssm,
  ]


}

resource "aws_cloudwatch_log_group" "eks_cluster_logs" {
  name              = "/aws/eks/${var.project_name}-eks-cluster/cluster"
  retention_in_days = 30

  tags = {
    Name = "${var.project_name}-eks-cluster-logs"
  }
}



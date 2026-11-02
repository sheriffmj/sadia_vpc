output "eks_cluster_arn" {
  value = aws_eks_cluster.eks_cluster.arn
}
output "eks_node_group_arn" {
  value = aws_eks_node_group.eks_node_group.arn
}
output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}
output "eks_node_group_name" {
  value = aws_eks_node_group.eks_node_group.node_group_name
}
output "eks_cluster_security_group_id" {
  value = aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id
}
output "eks_node_role_arn" {
  value = aws_iam_role.eks_nodegroup.arn
}

output "log_group_name" {
  value = aws_cloudwatch_log_group.eks_cluster_logs.name
}


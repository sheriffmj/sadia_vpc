project_name            = "sadia"
aws_region              = "us-east-1"
availability_zone_count = 3 #aware of cost associeated with the endpoints. running destroy workflow right after deployment.
vpc_cidr                = "10.0.0.0/16"
inbound_web_cidr        = ["0.0.0.0/0"]
environment             = "dev"
owner                   = "Palmer"
kubernetes_version      = "1.37"
node_groups = {
  main = {
    desired_size  = 9
    max_size      = 12
    min_size      = 9
    instance_type = "m5.xlarge"
  }
}
retention_in_days         = 90
enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
nodes_ami_type            = "AL2023_x86_64_STANDARD"
output "vpc_id" {
  value       = aws_vpc.main.id
  description = "The Unique ID of the main VPC"
}

output "public_subnet_ids" {
  value       = [for subnet in aws_subnet.public_subnets : subnet.id]
  description = "A list of IDs of the public subnets"
}

output "private_subnet_ids" {
  value       = [for subnet in aws_subnet.private_subnets : subnet.id]
  description = "A list of IDs of the private subnets"
}

output "db_private_subnet_ids" {
  value       = [for subnet in aws_subnet.db_private_subnets : subnet.id]
  description = "A list of IDs of the DB private subnets"
}

output "alb_sg_id" {
  value       = aws_security_group.alb_sg.id
  description = "The ID of the ALB security group"
}

output "app_sg_id" {
  value       = aws_security_group.app_sg.id
  description = "The ID of the application security group"
}

output "db_sg_id" {
  value       = aws_security_group.db_sg.id
  description = "The ID of the Database security group"
}

output "db_subnet_group_name" {
  value       = aws_db_subnet_group.db_subnet_group.name
  description = "The name of the DB subnet group"
}

output "endpoints_sg_id" {
  value       = aws_security_group.endpoints_sg.id
  description = "The ID of the VPC interface endpoints security group"
}

output "s3_prefix_list_id" {
  value       = aws_vpc_endpoint.s3_gateway.prefix_list_id
  description = "The prefix list ID of the S3 gateway VPC endpoint, for client SG egress rules"
}

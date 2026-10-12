output "vpc_id" {
  value = aws_vpc.main.id
  description = "The Unique ID of the main VPC"
}

output "public_subnet_ids" {
  value = [for subnet in aws_subnet.public_subnets : subnet.id]
  description = "A list of IDs of the public subnets"
}

output "private_subnet_ids" {
  value = [for subnet in aws_subnet.private_subnets : subnet.id]
  description = "A list of IDs of the private subnets"
}

output "db_private_subnet_ids" {
  value = [for subnet in aws_subnet.db_private_subnets : subnet.id]
  description = "A list of IDs of the DB private subnets"
}

output "web_sg_id" {
  value = aws_security_group.web_sg.id
  description = "The ID of the web security group"
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
  description = "The ID of the Database security group"
}

output "aws_nat_gateway_ids" {
  value = [for nat in aws_nat_gateway.nat_gw : nat.id]
  description = "A list of IDs of the NAT gateways"
}

output "nat_gateway_public_ips" {
  value = [for eip in aws_eip.nat_eip : eip.public_ip]
  description = "A list of public Elastic IPs bound to the NAT gateways"
}

output "db_subnet_group_names" {
  value = aws_db_subnet_group.db_subnet_group.name
  description = "The name of the DB subnet group"
}

output "ubuntu_ami_id" {
  value = data.aws_ami.ubuntu.id
  description = "The ID of the Ubuntu AMI"
}
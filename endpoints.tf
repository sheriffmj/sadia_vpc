resource "aws_vpc_endpoint" "ssm" {
  for_each            = toset(var.ssm_services)
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoints_sg.id]
  subnet_ids          = [for subnet in aws_subnet.private_subnets : subnet.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-ssm-endpoint-${each.key}"
  }
}

resource "aws_vpc_endpoint" "s3_gateway" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = [
    aws_route_table.private_rt.id,
  ]
  tags = {
    Name = "${var.project_name}-s3-gateway-endpoint"
  }
}


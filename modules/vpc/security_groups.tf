resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-default-sg"
  }
}

resource "aws_security_group" "endpoints_sg" {
  name        = "${var.project_name}-endpoints-sg"
  description = "Security group for VPC interface endpoints"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-endpoints-sg"
  }
}

resource "aws_security_group_rule" "endpoints_from_clients" {
  for_each                 = var.endpoint_client_security_group_ids
  type                     = "ingress"
  description              = "Allow inbound HTTPS access to VPC interface endpoints from ${each.key}"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.endpoints_sg.id
  source_security_group_id = each.value
}

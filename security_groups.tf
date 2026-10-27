resource "aws_security_group" "alb_sg" {
  name        = "${var.project_name}-alb-sg"
  description = "Security group for ALB"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-alb-sg"
  }
}

resource "aws_security_group_rule" "alb_allow_http" {
  type              = "ingress"
  description       = "Allow inbound HTTP access to ALB"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.inbound_web_cidr
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_allow_https" {
  type              = "ingress"
  description       = "Allow inbound HTTPS access to ALB"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.inbound_web_cidr
  security_group_id = aws_security_group.alb_sg.id
}

resource "aws_security_group_rule" "alb_outbound_to_app" {
  type                     = "egress"
  description              = "Allow outbound traffic from ALB to application servers"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.alb_sg.id
  source_security_group_id = aws_security_group.app_sg.id
}

resource "aws_security_group" "app_sg" {
  name        = "${var.project_name}-app-sg"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-app-sg"
  }
}

resource "aws_security_group_rule" "app_inbound_http" {
  type                     = "ingress"
  description              = "Allow inbound HTTP access"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb_sg.id
  security_group_id        = aws_security_group.app_sg.id
}

resource "aws_security_group_rule" "app_egress_ssm" {
  type                     = "egress"
  description              = "Allow outbound traffic from application servers to SSM VPC interface endpoints"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.endpoints_sg.id
}

resource "aws_security_group_rule" "app_egress_s3" {
  type              = "egress"
  description       = "Allow outbound traffic from application servers to S3"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.app_sg.id
  prefix_list_ids   = [aws_vpc_endpoint.s3_gateway.prefix_list_id]
}

resource "aws_security_group_rule" "app_egress_mysql" {
  type                     = "egress"
  description              = "Allow outbound traffic from application servers to MySQL"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_sg.id
  source_security_group_id = aws_security_group.db_sg.id
}

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for database servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_security_group_rule" "db_allow_mysql" {
  type                     = "ingress"
  description              = "Allow MySQL access from the application security group"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.db_sg.id
  source_security_group_id = coalesce(var.allowed_app_sg_id, aws_security_group.app_sg.id)
}

resource "aws_security_group" "endpoints_sg" {
  name        = "${var.project_name}-endpoints-sg"
  description = "Security group for SSM VPC interface endpoints"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "Allow inbound HTTPS access to SSM VPC interface endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }

  tags = {
    Name = "${var.project_name}-endpoints-sg"
  }
}

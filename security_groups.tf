resource "aws_security_group" "web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-web-sg"
  }
}

resource "aws_security_group_rule" "web_allow_all_outbound" {
  type              = "egress"
  description       = "Allow all outbound traffic"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.open_internet]
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "inbound_http" {
  type              = "ingress"
  description       = "Allow inbound HTTP access"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = var.inbound_web_cidr
  security_group_id = aws_security_group.web_sg.id
}

resource "aws_security_group_rule" "inbound_https" {
  type              = "ingress"
  description       = "Allow inbound HTTPS access"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = var.inbound_web_cidr
  security_group_id = aws_security_group.web_sg.id
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
  source_security_group_id = coalesce(var.allowed_app_sg_id, aws_security_group.web_sg.id)
}

resource "aws_security_group" "endpoints_sg" {
  name        = "${var.project_name}-endpoints-sg"
  description = "Security group for SSM VPC interface endpoints"
  vpc_id      = aws_vpc.main.id
  ingress {
    description = "Allow inbound HTTPS access to SSM VPC interface endpoints"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    security_groups = [aws_security_group.web_sg.id]
  }

  tags = {
    Name = "${var.project_name}-endpoints-sg"
  }
}

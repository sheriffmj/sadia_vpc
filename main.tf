data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}
variable "availability_zone_count" {
  description = "The number of availability zones to use"
  type        = number
  default     = 3
}
locals {
  selected_azs = slice(data.aws_availability_zones.available.names, 0, var.availability_zone_count)
  subnet_config = {
    for idx, az in local.selected_azs : az => {
      az_name         = az
      public_cidr     = cidrsubnet(var.vpc_cidr, 8, idx)
      private_cidr    = cidrsubnet(var.vpc_cidr, 8, idx + var.availability_zone_count)
      db_private_cidr = cidrsubnet(var.vpc_cidr, 8, idx + var.availability_zone_count * 2)
    }
  }
}

resource "aws_vpc" "sadia_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "sadia_public_subnets" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.sadia_vpc.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.value.az_name
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "sadia_private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.sadia_vpc.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.value.az_name

  tags = {
    Name = "${var.project_name}-private-subnet-${each.key}"
  }
}

resource "aws_subnet" "sadia_db_private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.sadia_vpc.id
  cidr_block        = each.value.db_private_cidr
  availability_zone = each.value.az_name

  tags = {
    Name = "${var.project_name}-db-private-subnet-${each.key}"
  }
}

resource "aws_internet_gateway" "sadia_igw" {
  vpc_id = aws_vpc.sadia_vpc.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "sadia_public_rt" {
  vpc_id = aws_vpc.sadia_vpc.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "sadia_public_internet_access" {
  route_table_id         = aws_route_table.sadia_public_rt.id
  destination_cidr_block = var.open_cidr
  gateway_id             = aws_internet_gateway.sadia_igw.id
}

resource "aws_route_table_association" "sadia_public_rt_assoc" {
  for_each = aws_subnet.sadia_public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.sadia_public_rt.id
}

resource "aws_eip" "sadia_nat_eip" {
  for_each   = local.subnet_config
  domain     = "vpc"
  depends_on = [aws_internet_gateway.sadia_igw]

  tags = {
    Name = "${var.project_name}-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "sadia_nat_gw" {
  for_each = local.subnet_config

  allocation_id = aws_eip.sadia_nat_eip[each.key].id
  subnet_id     = aws_subnet.sadia_public_subnets[each.key].id
  depends_on    = [aws_internet_gateway.sadia_igw]

  tags = {
    Name = "${var.project_name}-nat-gw-${each.key}"
  }
}
resource "aws_route_table" "sadia_private_rt" {
  for_each = aws_subnet.sadia_private_subnets
  vpc_id   = aws_vpc.sadia_vpc.id

  tags = {
    Name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route" "sadia_private_nat_access" {
  for_each = aws_route_table.sadia_private_rt

  route_table_id         = each.value.id
  destination_cidr_block = var.open_cidr
  nat_gateway_id         = aws_nat_gateway.sadia_nat_gw[each.key].id
}

resource "aws_route_table_association" "sadia_private_rt_assoc" {
  for_each = aws_subnet.sadia_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.sadia_private_rt[each.key].id
}

resource "aws_route_table" "sadia_db_private_rt" {
  for_each = aws_subnet.sadia_db_private_subnets
  vpc_id   = aws_vpc.sadia_vpc.id

  tags = {
    Name = "${var.project_name}-db-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "sadia_db_private_rt_assoc" {
  for_each = aws_subnet.sadia_db_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.sadia_db_private_rt[each.key].id
}

resource "aws_security_group" "sadia_web_sg" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for web servers"
  vpc_id      = aws_vpc.sadia_vpc.id
}

resource "aws_security_group_rule" "web_allow_ssh" {
  type              = "ingress"
  from_port         = 22
  to_port           = 22
  protocol          = "tcp"
  cidr_blocks       = [var.allow_ssh_cidr]
  security_group_id = aws_security_group.sadia_web_sg.id
}

resource "aws_security_group_rule" "web_allow_all_outbound" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [var.open_cidr]
  security_group_id = aws_security_group.sadia_web_sg.id
}

resource "aws_security_group_rule" "web_allow_http" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = [var.open_cidr]
  security_group_id = aws_security_group.sadia_web_sg.id
}

resource "aws_security_group_rule" "web_allow_https" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = [var.open_cidr]
  security_group_id = aws_security_group.sadia_web_sg.id
}

resource "aws_security_group" "sadia_db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Security group for database servers"
  vpc_id      = aws_vpc.sadia_vpc.id

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

resource "aws_security_group_rule" "db_allow_mysql" {
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sadia_db_sg.id
  source_security_group_id = aws_security_group.sadia_web_sg.id
}

resource "aws_db_subnet_group" "sadia_db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.sadia_db_private_subnets : subnet.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

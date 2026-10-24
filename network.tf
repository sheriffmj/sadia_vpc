resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.value.az_name
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.value.az_name

  tags = {
    Name = "${var.project_name}-private-subnet-${each.key}"
  }
}

resource "aws_subnet" "db_private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.db_private_cidr
  availability_zone = each.value.az_name

  tags = {
    Name = "${var.project_name}-db-private-subnet-${each.key}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route" "public_internet_access" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = local.open_internet
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_rt_assoc" {
  for_each = aws_subnet.public_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}
resource "aws_route_table_association" "private_rt_assoc" {
  for_each = aws_subnet.private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table" "db_private_rt" {
  for_each = aws_subnet.db_private_subnets
  vpc_id   = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-db-private-rt-${each.key}"
  }
}

resource "aws_route_table_association" "db_private_rt_assoc" {
  for_each = aws_subnet.db_private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db_private_rt[each.key].id
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = [for subnet in aws_subnet.db_private_subnets : subnet.id]

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

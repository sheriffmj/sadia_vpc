resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public_subnets" {
  for_each = local.subnet_config

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.public_cidr
  availability_zone       = each.value.az_name
  map_public_ip_on_launch = true

  tags = {
    name = "${var.project_name}-public-subnet-${each.key}"
  }
}

resource "aws_subnet" "private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.private_cidr
  availability_zone = each.value.az_name

  tags = {
    name = "${var.project_name}-private-subnet-${each.key}"
  }
}

resource "aws_subnet" "db_private_subnets" {
  for_each = local.subnet_config

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value.db_private_cidr
  availability_zone = each.value.az_name

  tags = {
    name = "${var.project_name}-db-private-subnet-${each.key}"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    name = "${var.project_name}-public-rt"
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

resource "aws_eip" "nat_eip" {
  for_each   = local.subnet_config
  domain     = "vpc"
  depends_on = [aws_internet_gateway.igw]

  tags = {
    name = "${var.project_name}-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each = local.subnet_config

  allocation_id = aws_eip.nat_eip[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    name = "${var.project_name}-nat-gw-${each.key}"
  }
}
resource "aws_route_table" "private_rt" {
  for_each = aws_subnet.private_subnets
  vpc_id   = aws_vpc.main.id

  tags = {
    name = "${var.project_name}-private-rt-${each.key}"
  }
}

resource "aws_route" "private_nat_access" {
  for_each = aws_route_table.private_rt

  route_table_id         = each.value.id
  destination_cidr_block = local.open_internet
  nat_gateway_id         = aws_nat_gateway.nat_gw[each.key].id
}

resource "aws_route_table_association" "private_rt_assoc" {
  for_each = aws_subnet.private_subnets

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private_rt[each.key].id
}

resource "aws_route_table" "db_private_rt" {
  for_each = aws_subnet.db_private_subnets
  vpc_id   = aws_vpc.main.id

  tags = {
    name = "${var.project_name}-db-private-rt-${each.key}"
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
    name = "${var.project_name}-db-subnet-group"
  }
}

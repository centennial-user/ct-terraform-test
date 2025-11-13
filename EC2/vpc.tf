// VPC
resource "aws_vpc" "private_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-vpc" })
}

// Subnets (created from a variable list)
resource "aws_subnet" "subnets" {
  for_each = { for s in var.subnets : s.name => s }

  vpc_id                  = aws_vpc.private_vpc.id
  cidr_block              = each.value.cidr
  availability_zone       = lookup(each.value, "availability_zone", data.aws_availability_zones.available.names[0])
  map_public_ip_on_launch = lookup(each.value, "map_public_ip_on_launch", false)

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-${each.key}" })
}

// Internet Gateway
resource "aws_internet_gateway" "public_igw" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-igw" })
}

// NAT Gateway (optional)
resource "aws_eip" "nat_eip" {
  count = var.create_nat ? 1 : 0
  tags  = merge(var.common_tags, { Name = "${var.name_prefix}-nat-eip" })
}

resource "aws_nat_gateway" "private_nat" {
  count         = var.create_nat ? 1 : 0
  allocation_id = aws_eip.nat_eip[0].id
  subnet_id     = aws_subnet.subnets[var.public_subnet_name].id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-nat" })
}

// Route Tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-public-rt" })
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.private_vpc.id

  tags = merge(var.common_tags, { Name = "${var.name_prefix}-private-rt" })
}

// Routes
resource "aws_route" "public_route" {
  route_table_id         = aws_route_table.public_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.public_igw.id
}

resource "aws_route" "private_route" {
  count                  = var.create_nat ? 1 : 0
  route_table_id         = aws_route_table.private_route_table.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.private_nat[0].id
}

// Subnet Associations
resource "aws_route_table_association" "public_subnet_association" {
  subnet_id      = aws_subnet.subnets[var.public_subnet_name].id
  route_table_id = aws_route_table.public_route_table.id
}


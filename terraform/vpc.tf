# A big thank you to https://spacelift.io/blog/terraform-aws-vpc for helping me to understand
# how to set up a VPC correctly.

# The main VPC which will be used by your app
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
}

# an internet gateway is necessary to give our VPC access to the outside world
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_vpc.main.main_route_table_id   # every VPC has an implicitly created main route table
  destination_cidr_block = "0.0.0.0/0"   # 0.0.0.0/0 allows full access to the internet – no restrictions
  gateway_id             = aws_internet_gateway.igw.id
}

# Iterate through the public_subnet_cidrs (defined in variables.tf) and create a subnet for each.
resource "aws_subnet" "public_subnets" {
  count             = length(var.public_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.public_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}

# we connect the public subnets to the internet gateway using a route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "public_subnet_asso" {
  count           = length(var.public_subnet_cidrs)
  subnet_id       = element(aws_subnet.public_subnets[*].id, count.index)
  route_table_id  = aws_route_table.public_route_table.id
}

# Each NAT has to have a public IP address
resource "aws_eip" "nat_eips" {
  domain            = "vpc"
  count             = length(var.public_subnet_cidrs)
}

# create one NAT in each public subnet
resource "aws_nat_gateway" "nat_gateways" {
  count             = length(aws_subnet.public_subnets)
  allocation_id     = element(aws_eip.nat_eips[*].id, count.index)
  subnet_id         = element(aws_subnet.public_subnets[*].id, count.index)

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.igw]
}

# create a route table for each private subnet to connect to the NAT in the public subnet in the same AZ
resource "aws_route_table" "private_route_table" {
  count             = length(aws_nat_gateway.nat_gateways)
  vpc_id            = aws_vpc.main.id

  route {
    cidr_block      = "0.0.0.0/0"
    nat_gateway_id  = element(aws_nat_gateway.nat_gateways[*].id, count.index)  # connect to a NAT, not an IGW
  }
}

# Iterate through the private_subnet_cidrs (defined in variables.tf) and create a subnet for each.
resource "aws_subnet" "private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = element(var.private_subnet_cidrs, count.index)
  availability_zone = element(var.azs, count.index)

  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

# Associate the private route tables with the private subnets
resource "aws_route_table_association" "private_subnet_asso" {
  count           = length(aws_route_table.private_route_table)
  subnet_id       = element(aws_subnet.private_subnets[*].id, count.index)
  route_table_id  = element(aws_route_table.private_route_table[*].id, count.index)
}

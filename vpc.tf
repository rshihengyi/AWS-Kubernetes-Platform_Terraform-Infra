resource "aws_vpc" "my_vpc" {

  region     = var.my_region
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name      = "My-VPC"
    Terraform = "true"
  }
}

# Public Subnets
resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = var.region_a

  tags = {
    Name = "public-subnet-1a"

    "kubernetes.io/cluster/My-Cluster" = "owned" // subnet only for My-Cluster cluster
    "kubernetes.io/role/elb"           = "1"     // internet facing load balancers, "1" = "true"
  }

  depends_on = [aws_vpc.my_vpc]
}

resource "aws_subnet" "public_1b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = var.region_b

  tags = {
    Name = "public-subnet-1b"

    "kubernetes.io/cluster/My-Cluster" = "owned"
    "kubernetes.io/role/elb"           = "1" // internet facing load balancers
  }
  depends_on = [aws_vpc.my_vpc]
}

# Private Subnets
resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.region_a

  tags = {
    Name = "private-subnet-1a"

    "kubernetes.io/cluster/My-Cluster" = "owned"
    "kubernetes.io/role/internal-elb"  = "1" // load balancer for resources inside VPC
  }
  depends_on = [aws_vpc.my_vpc]
}

resource "aws_subnet" "private_1b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = var.region_b

  tags = {
    Name = "private-subnet-1b"

    "kubernetes.io/cluster/My-Cluster" = "owned"
    "kubernetes.io/role/internal-elb"  = "1" // load balancer for resources inside VPC
  }
  depends_on = [aws_vpc.my_vpc]
}

# Private Subnets for RDS
resource "aws_subnet" "private_RDS_a" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.7.0/24"
  availability_zone = var.region_a

  tags = {
    Name = "private-subnet-RDS-a"
  }
}

resource "aws_subnet" "private_RDS_b" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.8.0/24"
  availability_zone = var.region_b

  tags = {
    Name = "private-subnet-RDS-b"
  }
}

resource "aws_db_subnet_group" "RDS_subnet" {
  subnet_ids = [
    aws_subnet.private_RDS_a.id,
    aws_subnet.private_RDS_b.id
  ]

  tags = {
    Name = "private-subnet-RDS"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "my_IWG" {
  vpc_id = aws_vpc.my_vpc.id
  region = var.my_region
  depends_on = [aws_vpc.my_vpc]
}

# Public Route Table

/* If traffic want to reach <cidr_block>, go to <gateway_id> */

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_IWG.id
  }
}

resource "aws_route_table_association" "public_association_a" {
  subnet_id      = aws_subnet.public_1a.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_association_b" {
  subnet_id      = aws_subnet.public_1b.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Tables
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GW_a.id
  }

  tags = { Name = "private-rt-1a" }
}

resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GW_b.id
  }

  tags = { Name = "private-rt-1b" }
}

resource "aws_route_table_association" "private_1a_worker" {

  subnet_id      = aws_subnet.private_1a.id
  route_table_id = aws_route_table.private_a.id
}

resource "aws_route_table_association" "private_1b_worker" {

  subnet_id      = aws_subnet.private_1b.id
  route_table_id = aws_route_table.private_b.id
}

# NAT Gateways
resource "aws_eip" "NAT_ip_a" {
  domain = "vpc"
}

resource "aws_eip" "NAT_ip_b" {
  domain = "vpc"
}

resource "aws_nat_gateway" "NAT_GW_a" {
  subnet_id     = aws_subnet.public_1a.id
  allocation_id = aws_eip.NAT_ip_a.id
  depends_on    = [aws_internet_gateway.my_IWG]
}

resource "aws_nat_gateway" "NAT_GW_b" {
  subnet_id     = aws_subnet.public_1b.id
  allocation_id = aws_eip.NAT_ip_b.id
  depends_on    = [aws_internet_gateway.my_IWG]
}

// Private Link between VPC and EKS
resource "aws_vpc_endpoint" "for_eks" {
  vpc_id            = aws_vpc.my_vpc.id
  service_name      = "com.amazonaws.${var.my_region}.eks-auth"
  vpc_endpoint_type = "Interface"

  tags = {
    Environment = "dev"
  }
}
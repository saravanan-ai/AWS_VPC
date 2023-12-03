################################
## AWS Provider Module - Main ##
################################

# AWS Provider
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  access_key = "XXXX"
  secret_key = "XXX"
  region     = "us-east-1"
}


# Creating a VPC inside AWS Account!
resource "aws_vpc" "testvpc" {
  
  # IP Range for the VPC
  cidr_block = "192.168.0.0/16"
  
  # Enabling automatic hostname assigning
  enable_dns_hostnames = true
  tags = {
    Name = "demo"
  }
}

# Creating Public subnet!
resource "aws_subnet" "publicsubnet" {
  depends_on = [
    aws_vpc.testvpc
  ]
  
  # VPC in which subnet has to be created!
  vpc_id = aws_vpc.testvpc.id
  
  # IP Range of this subnet
  cidr_block = "192.168.0.0/24"
  
  # Data Center of this subnet.
  availability_zone = "us-east-1a"
  
  # Enabling automatic public IP assignment on instance launch!
  map_public_ip_on_launch = true

  tags = {
    Name = "Public Subnet"
  }
}


# Creating Private  subnet!
resource "aws_subnet" "privatesubnet" {
  depends_on = [
    aws_vpc.testvpc,
    aws_subnet.publicsubnet
  ]
  
  # VPC in which subnet has to be created!
  vpc_id = aws_vpc.testvpc.id
  
  # IP Range of this subnet
  cidr_block = "192.168.1.0/24"
  
  # Data Center of this subnet.
  availability_zone = "us-east-1b"
  
  tags = {
    Name = "Private Subnet"
  }
}

# Creating an Internet Gateway for the VPC
resource "aws_internet_gateway" "Internet_Gateway" {
  depends_on = [
    aws_vpc.testvpc,
    aws_subnet.publicsubnet,
    aws_subnet.privatesubnet
  ]
  
  # VPC in which it has to be created!
  vpc_id = aws_vpc.testvpc.id

  tags = {
    Name = "IG-Public-&-Private-VPC"
  }
}

# Creating an Route Table for the public subnet!
resource "aws_route_table" "Public-Subnet-RT" {
  depends_on = [
    aws_vpc.testvpc,
    aws_internet_gateway.Internet_Gateway
  ]

   # VPC ID
  vpc_id = aws_vpc.testvpc.id

  # NAT Rule
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Internet_Gateway.id
  }

  tags = {
    Name = "Route Table for Internet Gateway"
  }
}

# Creating a resource for the Route Table Association!
resource "aws_route_table_association" "RT-IG-Association" {

  depends_on = [
    aws_vpc.testvpc,
    aws_subnet.publicsubnet,
    aws_subnet.privatesubnet,
    aws_route_table.Public-Subnet-RT
  ]

# Public Subnet ID
  subnet_id      = aws_subnet.publicsubnet.id

#  Route Table ID
  route_table_id = aws_route_table.Public-Subnet-RT.id
}

# Creating an Elastic IP for the NAT Gateway!
resource "aws_eip" "Nat-Gateway-EIP" {
  depends_on = [
    aws_route_table_association.RT-IG-Association
  ]
  vpc = true
}


# Creating a NAT Gateway!
resource "aws_nat_gateway" "NAT_GATEWAY" {
  depends_on = [
    aws_eip.Nat-Gateway-EIP
  ]

  # Allocating the Elastic IP to the NAT Gateway!
  allocation_id = aws_eip.Nat-Gateway-EIP.id
  
  # Associating it in the Public Subnet!
  subnet_id = aws_subnet.publicsubnet.id
  tags = {
    Name = "Nat-Gateway_Project"
  }
}


# Creating a Route Table for the Nat Gateway!
resource "aws_route_table" "NAT-Gateway-RT" {
  depends_on = [
    aws_nat_gateway.NAT_GATEWAY
  ]

  vpc_id = aws_vpc.testvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT_GATEWAY.id
  }

  tags = {
    Name = "Route Table for NAT Gateway"
  }

}


# Creating an Route Table Association of the NAT Gateway route  table with the Private Subnet!
resource "aws_route_table_association" "Nat-Gateway-RT-Association" {
  depends_on = [
    aws_route_table.NAT-Gateway-RT
  ]

#  Private Subnet ID for adding this route table to the DHCP server of Private subnet!
  subnet_id      = aws_subnet.privatesubnet.id

# Route Table ID
  route_table_id = aws_route_table.NAT-Gateway-RT.id
}

provider "aws" {
  region = "us-west-2"
}

# ======= VPC  =======
# At first create VPC for our wordpress application
resource "aws_vpc" "alex_sbk_vpc_for_wordpress" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "Wordpress_best_practice"
  }
}

# ======= PUBLIC SUBNETS ==========
# Now create 2 subnets for
# 2 separate availability Zones in one VPC
# for High availability and so on

# At first get info about availability zones in current region
# We'll create two subnets in different availability zones
# So we need to know which zones is available
data "aws_availability_zones" "current_zones_info" {}

# And create the public subnets: A and B
resource "aws_subnet" "Subnet_A_public" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.11.0/24"
  availability_zone = data.aws_availability_zones.current_zones_info.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "Subnet_A_public"
  }
}

resource "aws_subnet" "Subnet_B_public" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.21.0/24"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.current_zones_info.names[1]
  tags = {
    Name = "Subnet_B_public"
  }
}

# ======= VPC INTERNET GATEWAY =======
# Next create internet gateway (not NAT Gateway)
# And attach it with our VPC
resource "aws_internet_gateway" "main_gateway_for_wordpress" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  tags = {
    Name = "IGW_for_wordpress"
  }
}

# ======= Public route tables =======
# Now let's create route table
# with default route for public subnets.
#
# We want all traffic from all instances in our public subnets
# to go to our default internet gateway (to the Internet)
# So do the next:
resource "aws_route_table" "alex_sbk_public_route_table_for_public_subnets" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_gateway_for_wordpress.id
  }
  tags = {
    Name = "public_route_table"
  }
}

# Making subnets truly public
# Adding public routes to them:

# Public Subnet A
resource "aws_route_table_association" "alex-sbk-public-route-association-A" {
  route_table_id = aws_route_table.alex_sbk_public_route_table_for_public_subnets.id
  subnet_id = aws_subnet.Subnet_A_public.id
}
# Public Subnet B
resource "aws_route_table_association" "alex-sbk-public-route-association-B" {
  route_table_id = aws_route_table.alex_sbk_public_route_table_for_public_subnets.id
  subnet_id = aws_subnet.Subnet_B_public.id
}

# ======= PRIVATE SUBNETS (Application Servers)==========
# Now create server subnets for Wordpress Instances

# Private App subnet A
resource "aws_subnet" "alex_sbk_wordpress_subnetA_private_app" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.12.0/24"
  availability_zone = data.aws_availability_zones.current_zones_info.names[0]
  tags = {
    Name = "01_Subnet_A_private_app"
  }
}
# Private App subnet B
resource "aws_subnet" "alex_sbk_wordpress_subnetB_private_app" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.22.0/24"
  availability_zone = data.aws_availability_zones.current_zones_info.names[0]
  tags = {
    Name = "02_Subnet_B_private_app"
  }
}

# ======= PRIVATE SUBNETS (DATABASES)==========
# Now create database subnets for Wordpress Databases

# Private Data Subnet A
resource "aws_subnet" "alex_sbk_wordpress_subnetA_private_data" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.13.0/24"
  availability_zone = data.aws_availability_zones.current_zones_info.names[0]
  tags = {
    Name = "03_Subnet_A_private_data"
  }
}

# Private Data Subnet B
resource "aws_subnet" "alex_sbk_wordpress_subnetB_private_data" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  cidr_block = "10.0.23.0/24"
  availability_zone = data.aws_availability_zones.current_zones_info.names[1]
  tags = {
    Name = "04_Subnet_B_private_data "
  }
}

# Create Elastic IP addresses for both public subnets
resource "aws_eip" "ip_of_subnet_A" {
  vpc = true
  tags = {
    Name = "Subnet-A-IP"
  }
}

resource "aws_eip" "ip_of_subnet_B" {
  vpc = true
  tags = {
    Name = "Subnet-B-IP"
  }
}

# Create NAT gateways in our public subnets
# And bind them with our public IP addresses:
resource "aws_nat_gateway" "NAT-A-Subnet" {
  allocation_id = aws_eip.ip_of_subnet_A.id
  subnet_id = aws_subnet.Subnet_A_public.id
  tags = {
    Name = "Subnet-A-NAT-Gateway"
  }
}

resource "aws_nat_gateway" "NAT-B-Subnet" {
  allocation_id = aws_eip.ip_of_subnet_B.id
  subnet_id = aws_subnet.Subnet_B_public.id
  tags = {
    Name = "Subnet-B-NAT-Gateway"
  }
}

# Create private route tables
resource "aws_route_table" "PrivateA-to-NAT-A" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  depends_on = [
    aws_nat_gateway.NAT-A-Subnet]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT-A-Subnet.id
  }
  tags = {
    Name = "Route-To-Nat-A"
  }
}

resource "aws_route_table" "PrivateB-to-NAT-B" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  depends_on = [
    aws_nat_gateway.NAT-B-Subnet]
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.NAT-B-Subnet.id
  }
  tags = {
    Name = "Route-To-Nat-B"
  }
}

# Associate our private subnets to our NAT gateways

# Private App subnet A
resource "aws_route_table_association" "association-subnet-app-A" {
  route_table_id = aws_route_table.PrivateA-to-NAT-A.id
  subnet_id = aws_subnet.alex_sbk_wordpress_subnetA_private_app.id
}
# Private App subnet B
resource "aws_route_table_association" "association-subnet-app-B" {
  route_table_id = aws_route_table.PrivateB-to-NAT-B.id
  subnet_id = aws_subnet.alex_sbk_wordpress_subnetB_private_app.id
}

# Data subnets has no outside routes


# ================== BASTION HOST!! ==================
# At first create security group for bastion host

resource "aws_security_group" "wordpress_bastion_ssh_access_group" {
  name = "SSH-Access-For-Bastion-Host"
  description = "SSH-Access-For-Bastion-Host"
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  tags = {
    Name = "Bastion-Host-Security-group"
  }
  # Allow incoming SSH packets from anywhere
  ingress {
    from_port = 22
    protocol = "tcp"
    to_port = 22
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  # Allow all outbound requests
  egress {
    from_port = 0
    protocol = -1
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }

}

# Create launch config for bastion hosts autoscaling group

resource "aws_launch_configuration" "wordpress_bastion_host" {
  image_id = "ami-0ac73f33a1888c64a"

  instance_type = "t2.micro"
  name = "Bastion-HOST-LC-instance"

  # this key was previously created by me.
  key_name = "oregon"

  # Using our security group
  security_groups = [
    aws_security_group.wordpress_bastion_ssh_access_group.id]

  # Required when using a launch configuration with an auto scaling group.
  lifecycle {
    create_before_destroy = false
  }
}

# Now create Auto scaling group for bastion host

resource "aws_autoscaling_group" "bastion-host-auto-scaling-group" {
  name = "bastion-host-ASG"
  launch_configuration = aws_launch_configuration.wordpress_bastion_host.name
  max_size = 0
  min_size = 0
  vpc_zone_identifier = toset([
    aws_subnet.Subnet_A_public.id,
    aws_subnet.Subnet_B_public.id])

  tag {
    key = "Name"
    propagate_at_launch = true
    value = "Bastion-host-ASG"
  }

}



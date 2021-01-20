 # At first create VPC for our worpress application

resource "aws_vpc" "alex_sbk_vpc_for_wordpress" {
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  tags = {
    Name = "alex_sbk_vpc_for_worpress_best_practice"
  }
}

 # Next create gateway
 # And attach it with our VPC
resource "aws_internet_gateway" "alex_sbk_gateway_for_worpress" {
  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
  tags = {
    Name = "alex_sbk_igw_for_wordpress"
  }
}

 # Now cteare 2 subnets for
 # 2 separate Aviability Zones in one VPC
 # for hight Aviability and so on

 # At first get info about Avalibility zones in current region
 data "aws_availability_zones" "current_zones_info" {

 }
 # And create the subnets: A and B

 resource "aws_subnet" "alex_sbk_wordpress_subnetA" {

  vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
   cidr_block = "10.0.11.0/24"
   availability_zone = data.aws_availability_zones.current_zones_info.names[0]
  tags = {
    Name = "Alex-Sbk-wordpress-subnet-SubnetA"
  }
}

 resource "aws_subnet" "alex_sbk_wordpress_subnetB" {

   vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
   cidr_block = "10.0.21.0/24"
   availability_zone = data.aws_availability_zones.current_zones_info.names[1]
   tags = {
     Name = "Alex-Sbk-wordpress-subnet-SubnetB"
   }
 }

 # Now let's create route table
 # with default route for public subnets
 resource "aws_route_table" "alex-sbk-public_route_table_for_public_subnets" {
   vpc_id = aws_vpc.alex_sbk_vpc_for_wordpress.id
   route {
     cidr_block = "0.0.0.0/0"
     gateway_id = aws_internet_gateway.alex_sbk_gateway_for_worpress.id
   }
   tags = {
     Name = "alex-sbk-public_route_table_for_public_subnets"
   }
 }

 # Make subnets really public
 # By adding public routes
 resource "aws_route_table_association" "alex-sbk-public-route-assotiation-A" {
   route_table_id = aws_route_table.alex-sbk-public_route_table_for_public_subnets.id
   subnet_id = aws_subnet.alex_sbk_wordpress_subnetA.id
 }
 resource "aws_route_table_association" "alex-sbk-public-route-assotiation-B" {
   route_table_id = aws_route_table.alex-sbk-public_route_table_for_public_subnets.id
   subnet_id = aws_subnet.alex_sbk_wordpress_subnetB.id
 }

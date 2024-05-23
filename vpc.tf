### VPC ###
resource "aws_vpc" "main" {
  cidr_block       = var.vpc_cidr
  instance_tenancy = "default"
  enable_dns_hostnames = var.enable_dns_hostnames

  tags = merge(
        var.common_tags,
        var.vpc_tags, 
        {
            Name = local.resource_name 
        }
  )
    
}

### IGW ###
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = merge(
    var.common_tags,
    var.igw_tags,
    {
        Name = local.resource_name
    }
  )
}

### public subnet ###
resource "aws_subnet" "public" { # first name is public[0], second name is public[1]
  count = length(var.public_subnet_cidrs)
  availability_zone = local.az_names[count.index]
  map_public_ip_on_launch = true # doubt
  vpc_id     = aws_vpc.main.id # doubt
  cidr_block = var.public_subnet_cidrs[count.index]
  tags = merge(
    var.common_tags,
    var.public_subnet_cidr_tags,
    {
        Name = "${local.resource_name}-public-${local.az_names[count.index]}" # this is called  as interpolation
    }
  )
}

### private subnet ###
resource "aws_subnet" "private" { # first name is private[0], second name is private[1]
  count = length(var.private_subnet_cidrs)
  availability_zone = local.az_names[count.index]
  #map_public_ip_on_launch = true # we dont need public ip in private subnet by default it is false
  vpc_id     = aws_vpc.main.id
  cidr_block = var.private_subnet_cidrs[count.index]
  tags = merge(
    var.common_tags,
    var.private_subnet_cidr_tags,
    {
        Name = "${local.resource_name}-private-${local.az_names[count.index]}"
    }
  )
}

### database subnet ###
resource "aws_subnet" "database" { # first name is database[0], second name is database[1]
  count = length(var.database_subnet_cidrs)
  availability_zone = local.az_names[count.index]
  #map_public_ip_on_launch = true # we dont need public ip in private subnet by default it is false
  vpc_id     = aws_vpc.main.id # doubt
  cidr_block = var.database_subnet_cidrs[count.index]
  tags = merge(
    var.common_tags,
    var.database_subnet_cidr_tags,
    {
        Name = "${local.resource_name}-databse-${local.az_names[count.index]}"
    }
  )
}

### database subnet group ###
resource "aws_db_subnet_group" "default" {
  name       = "${local.resource_name}"
  subnet_ids = aws_subnet.database[*].id

  tags = merge(
    var.common_tags,
    var.database_subnet_group_tags,
    {
        Name = "${local.resource_name}" #expense-dev
    }
  )
}


### elastic ip ###
resource "aws_eip" "eip" {
  domain   = "vpc"
}

### nat gateway (NAT-GW) ###
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public[0].id

  tags =  merge(
    var.common_tags,
    var.nat_gateway_tags,
    {
        Name = "${local.resource_name}" #expense-dev
    }
  )

  # To ensure proper ordering, it is recommended to add an explicit dependency
  # on the Internet Gateway for the VPC.
  depends_on = [aws_internet_gateway.gw] # this is explicit dependency
}

### public Route table ###
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id


  tags = merge(
    var.common_tags,
    var.public_route_table_tags,
    {
        Name = "${local.resource_name}-public" #expense-dev-public
    }
  )
}

### private Route table ###
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id


  tags = merge(
    var.common_tags,
    var.private_route_table_tags,
    {
        Name = "${local.resource_name}-private" #expense-dev-private
    }
  )
}

### database Route table ###
resource "aws_route_table" "database" {
  vpc_id = aws_vpc.main.id


  tags = merge(
    var.common_tags,
    var.database_route_table_tags,
    {
        Name = "${local.resource_name}-database" #expense-dev-database
    }
  )
}

### public route ###
resource "aws_route" "public_route_gw" {
  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.gw.id
}

### private route ###
resource "aws_route" "private_route_nat" {
  route_table_id            = aws_route_table.private.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

### database route ###
resource "aws_route" "database_route_nat" {
  route_table_id            = aws_route_table.database.id
  destination_cidr_block    = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat.id
}

### route table and subnet association to public subnets ###
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)
  subnet_id      = element(aws_subnet.public[*].id, count.index) # To select perticular element: element(list, index)
  route_table_id = aws_route_table.public.id
}

### route table and subnet association to private subnets ###
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.private.id
}

### route table and subnet association to database subnets ###
resource "aws_route_table_association" "database" {
  count = length(var.database_subnet_cidrs)
  subnet_id      = element(aws_subnet.database[*].id, count.index)
  route_table_id = aws_route_table.database.id
}



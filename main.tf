provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      App = "App Migration"
    }
  }
}

#local variables
locals {
  cidrs-azs = {
    private-subnet-1 = {cidr = var.ps1c, zone = "us-east-1a"}
    private-subnet-2 = {cidr = var.ps2c, zone = "us-east-1b"}
  }
  instances = {
    app-host-1 = ""
    app-host-2 = ""
  }
}

# private subnets
resource "aws_subnet" "private-subnet" {
  vpc_id = var.my-vpc-id
  for_each = local.cidrs-azs
  cidr_block = each.value.cidr
  availability_zone = each.value.zone
  tags = {
    Name = each.key
  }
}

# app host instances
resource "aws_instance" "app-host" {
  for_each = local.instances
  count = 2
  ami = var.ah-ami
  vpc_security_group_ids = [aws_security_group.allow-elb-bastion-apphost.id]
  instance_type = "t2.micro"
  subnet_id = aws_subnet.private-subnet[count.index].id
  #depends_on = [aws_subnet.private-subnet]
  tags = {
    Name = each.key
  }
}

#app host security group
resource "aws_security_group" "allow-elb-bastion-apphost" {
  description = "Allow SSH 22 from bastion and 80/443 from ELB"
  vpc_id = var.my-vpc-id
  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    security_groups = [aws_security_group.allow-web-elb.id]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.allow-web-elb.id]
  }
  ingress {
    description = "SSH"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [var.bastion-host-sg]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
}

#nat gateway elastic ip
resource "aws_eip" "nat-eip" {
  vpc = true
  depends_on = var.igw-id
}

#nat gateway
resource "aws_nat_gateway" "NAT-gateway" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id = var.public-subnet-id
  connectivity_type = "public"
}

#nat gateway route to internet
resource "aws_route" "nat-out" {
  route_table_id = var.my-route-table-id
  destination_cidr_block = 0.0.0.0/0
  nat_gateway_id = aws_nat_gateway.NAT-gateway.id
}

#load balancer
resource "aws_lb" "public-elb" {
  internal = false
  load_balancer_type = "network"
  subnets = var.public-subnet-id
  security_group = aws_security_group.allow-web-elb.id
  enable_deletion_protection = true
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "public-elb"
  }
}

#load balancer target group
resource "aws_lb_target_group" "lb-tg" {
  name = "lb-target-group"
  port = "80"
  vpc_id = var.my-vpc-id
  health_check {
    healthy_threshold = "3"
    interval = "30"
    protocol = "HTTP"
  }
  depend_on = [aws_lb.public-elb]
}

#target group association
resource "aws_target_group_attachment" "elb-targets" {
  for_each {
    for k, v in aws_instance.app-host :
    v.id => v
  }
  target-group-arn = aws_lb_target_group.lb-tg.arn
  target_id = each.value.id
  port = 80
}

#load balancer security group
resource "aws_security_group" "allow-web-elb" {
  description = "Allow inbound traffic on ports 80, 443"
  vpc-id = var.my-vpc-id
  ingress {
    description = "HTTPS"
    form_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = [0.0.0.0/0]
  }
  ingress {
    description = "HTTP"
    form_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [0.0.0.0/0]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
}

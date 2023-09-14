provider "aws" {
  region = "us-east-1"
  default_tags {
    tags = {
      App = "App Migration"
    }
  }
}

#outputs
output "subnet_id_set" {
  value = data.aws_subnets.private.ids
}
output "instance_id_set" {
  value = data.aws_instances.app-hosts.ids
}

#data sources
data "aws_subnets" "private" {
  filter {
    name = "vpc-id"   
    values = [var.my-vpc-id]
  }
  tags = {
    Data = "subnet"
  }
  depends_on = [aws_subnet.private-subnet]
}
data "aws_instances" "app-hosts" {
  filter {
    name = "tag:Data"
    values = ["app-hosts"]
  }
  depends_on = [aws_instance.app-host]
}

#local variables
locals {
  cidrs-azs = {
    private-subnet-1 = {cidr = var.ps1c, zone = "us-east-1a"}
    private-subnet-2 = {cidr = var.ps2c, zone = "us-east-1b"}
  }
}

# public subnet for lb
resource "aws_subnet" "public-subnet" {
  vpc_id = var.my-vpc-id
  cidr_block = "172.31.3.0/24"
  availability_zone = "us-east-1b"
  tags = {
    Name = "public-subnet-2"
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
    Data = "subnet"
  }
}

# app host instances
resource "aws_instance" "app-host" {
  count = var.resource-count
  ami = var.ah-ami
  vpc_security_group_ids = [aws_security_group.allow-elb-bastion-apphost.id]
  instance_type = "t2.micro"
  key_name = "bastion-access"
  subnet_id = data.aws_subnets.private.ids[count.index]
  tags = {
    Name = "app-host-${count.index}"
    Data = "app-hosts"
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
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#create private subnet route table
resource "aws_route_table" "private-rt" {
  vpc_id = var.my-vpc-id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.NAT-gateway.id
  }
  tags = {
    Name = "private-rt"
  }
}

#associate route table with private subnets
resource "aws_route_table_association" "rt-ass"{
  count = var.resource-count
  subnet_id = data.aws_subnets.private.ids[count.index]
  route_table_id = aws_route_table.private-rt.id
}

#nat gateway elastic ip
resource "aws_eip" "nat-eip" {
  domain = "vpc"
  depends_on = [var.igw-id]
}

#nat gateway
resource "aws_nat_gateway" "NAT-gateway" {
  allocation_id = aws_eip.nat-eip.id
  subnet_id = var.public-subnet-id
  connectivity_type = "public"
}

resource "aws_lb" "public-elb" {
  internal = false
  load_balancer_type = "application"
  subnets = [var.public-subnet-id, aws_subnet.public-subnet.id]
  security_groups = [aws_security_group.allow-web-elb.id]
  enable_cross_zone_load_balancing = true
  tags = {
    Name = "public-elb"
  }
}

#load balancer target group
resource "aws_lb_target_group" "lb-tg" {
  name = "lb-target-group"
  port = "80"
  protocol = "HTTP"
  vpc_id = var.my-vpc-id
  health_check {
    healthy_threshold = "3"
    interval = "30"
    protocol = "HTTP"
  }
  depends_on = [aws_lb.public-elb]
}

#target group association
resource "aws_lb_target_group_attachment" "elb-targets" {
  count = var.resource-count
  target_group_arn = aws_lb_target_group.lb-tg.arn
  target_id = data.aws_instances.app-hosts.ids[count.index]
  port = 80
  depends_on = [aws_instance.app-host]
}

#target group listener to lb
resource "aws_lb_listener" "lb-listener" {
  load_balancer_arn = aws_lb.public-elb.arn
  port = "80"
  protocol = "HTTP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.lb-tg.arn
  } 
}

#load balancer security group
resource "aws_security_group" "allow-web-elb" {
  description = "Allow inbound traffic on ports 80, 443"
  vpc_id = var.my-vpc-id
  ingress {
    description = "HTTPS"
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
  }
}

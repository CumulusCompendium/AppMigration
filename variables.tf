variable "my-vpc-id" {
  description = "VPC ID"
  default     = "vpc-07989cc04f4966ee5"
}

variable "ps1c" {
  description = "private subnet 1 cidr"
  default     = "172.31.1.0/24"
}

variable "ps2c" {
  description = "private subnet 2 cidr"
  default = "172.31.2.0/24"
}

variable "ah-ami" {
  description = "app host ami"
  default = "ami-0453898e98046c639"
}

variable "bastion-host-sg" {
  description = "bastion host security group"
  default = "sg-038074cd79522a0d2"
}

variable "public-subnet-id" {
  description = "public subnet id"
  default = "subnet-03c14ae5b0481b727"
}

variable "my-route-table-id" {
  description = "default route table id"
  default = "rtb-0979817af510a87e4"
}

variable "igw-id" {
  description = "internet gateway ID"
  default = "igw-07d04803c9c40f77f"
}

variable "resource-count" {
  description = "count of subnets, instances, and lb-targets"
  default = 2
}

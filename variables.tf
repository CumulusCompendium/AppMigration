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

variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "key_name" {
  default = "cba_keypair1"
}

variable "subnets_public" {
    type = list
    default = ["aws_subnet.cba_public1","aws_subnet.cba_public2"]
}

variable "subnets_private" {
    type = list
    default = ["aws_subnet.cba_private1","aws_subnet.cba_private2"]
}



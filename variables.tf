variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t2.micro"
}

variable "instance_ami" {
  default = "ami-0bb4c991fa89d4b9b"
}


variable "vpc_id" {
  default = ""
}


variable "key_name" {
  default = "cba_keypair1"
}
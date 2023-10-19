variable "region" {
  default = "eu-west-1"
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

variable "subnets" {
   type = list
   default = ["aws_subnet.cba_public1","aws_subnet.cba_public2","aws_subnet.cba_private1","aws_subnet.cba_private2"]
}

variable "db_username" {
  description = "Username for the RDS instance"
  default     = "mydb"
}

variable "db_password" {
  description = "Password for the RDS instance"
  default     = "mydbinstancepassword"
}

variable "db_name" {
  description = "Database name"
  default     = "mydb"
}

variable "target_group_arn" {
    type = list
    default = ["aws_lb_target_group.alb-target-group.arn", "aws_lb_target_group.alb-target-group2.arn"]
}
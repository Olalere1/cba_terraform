provider "aws" {
 region = var.region
}

resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"
  instance_tenancy     = "default"

  tags = {
    name = "ApacheVPC"
  }
}

# Create a new security group for the load balancer
resource "aws_security_group" "sg_lb" {
  name   = "sg_lb"
  vpc_id = aws_vpc.my_vpc.id

  # HTTP access from anywhere
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access from anywhere
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Instance Security group (traffic ALB -> EC2, ssh -> EC2)
resource "aws_security_group" "cba_tf_sg" {
  name        = "cba_tf_sg"
  description = "Allows inbound access from the ALB only"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.sg_lb.id]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
   name = "CBAterraformSG"
}
}

resource "aws_internet_gateway" "cba_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "ApacheIGW"
  }
}

resource "aws_subnet" "cba_public1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1a"

  tags = {
    Name = "ApachePublicSubnet1"
  }
}

resource "aws_subnet" "cba_public2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = "true"
  availability_zone       = "eu-west-1b"

  tags = {
    Name = "ApachePublicSubnet2"
  }
}

resource "aws_subnet" "cba_private1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "eu-west-1a"

  tags = {
    Name = "ApachePrivateSubnet1"
  }
}

resource "aws_subnet" "cba_private2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.4.0/24"
  map_public_ip_on_launch = "false"
  availability_zone       = "eu-west-1b"

  tags = {
    Name = "ApachePrivateSubnet2"
  }
}

resource "aws_route_table" "cba_public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.cba_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id = aws_internet_gateway.cba_igw.id
  }

  tags = {
    Name = "ApachePublicRT"
  }
}

# Creating a NAT gateway to be attached to the private route table

resource "aws_nat_gateway" "CustomNAT" {
  subnet_id     = aws_subnet.cba_public1

  tags = {
    Name = "CustomNAT"
  }
}

# Creating a private route table with NAT gateway attached

resource "aws_route_table" "cba_private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.CustomNAT.id
  }

  tags = {
    Name = "PrivateRouteTable"
  }
}

resource "aws_route_table_association" "cba_subnet_rt_public" {
  subnet_id      = "aws_subnet.cba_public1.id"
  route_table_id = aws_route_table.cba_public_rt.id
}

resource "aws_route_table_association" "cba_subnet_rt_private" {
  subnet_id      = "aws_subnet.cba_private1.id"
  route_table_id = aws_route_table.cba_private_rt.id
}


data "aws_ssm_parameter" "instance_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_key_pair" "sample_kp" {
  key_name = var.key_name
}

resource "aws_instance" "cba_tf_instance1" {
  ami             = data.aws_ssm_parameter.instance_ami.value
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.cba_public1.id
  security_groups = [aws_security_group.cba_tf_sg.id]
  key_name        = var.key_name
  user_data       = fileexists("install_apache.sh") ? file("install_apache.sh") : null


  tags = {
    "NAME" = "ApacheInstance"
  }

}

#nat_gateway_id = aws_nat_gateway.CustomNAT.id as security group for the private instance

resource "aws_instance" "cba_tf_instance2" {
  ami             = data.aws_ssm_parameter.instance_ami.value
  instance_type   = var.instance_type
  subnet_id       = aws_subnet.cba_private1.id
  security_groups = [aws_nat_gateway.CustomNAT.id]
  key_name        = var.key_name
 
  tags = {
    "NAME" = "PrivateInstance"
  }

}

# Create a public load balancer
resource "aws_lb" "loadbalancer_public" {
  name            = "loadbalancer-public"
  load_balancer_type = "application" 
  subnets         = var.subnets_public
  security_groups = [aws_security_group.sg_lb.id]
  internal        = "false"
  enable_cross_zone_load_balancing = "true"
}

resource "aws_lb_target_group" "alb-target-group" {
  name     = "alb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health.html"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}


# Create a private load balancer
resource "aws_lb" "loadbalancer_private" {
  name            = "loadbalancer-private"
  load_balancer_type = "application" 
  subnets         = var.subnets_private
  security_groups = [aws_nat_gateway.CustomNAT.id]
  internal        = "true"
  enable_cross_zone_load_balancing = "true"
}

resource "aws_lb_target_group" "alb-target-group2" {
  name     = "alb-target-group2"
  port     = 80
  protocol = "tcp"
  vpc_id   = aws_vpc.my_vpc.id
  target_type = "instance"

  health_check {
    enabled             = true
    interval            = 30
    path                = "/health.html"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_launch_configuration" "ec2" {
  name                        = "ec2-launch-config"
  image_id                    = data.aws_ssm_parameter.instance_ami.value
  instance_type               = "${var.instance_type}"
  security_groups             = [aws_security_group.cba_tf_sg.id]
  key_name                    = var.key_name
  iam_instance_profile        = aws_iam_instance_profile.session-manager.id
  associate_public_ip_address = false
}


resource "aws_autoscaling_group" "autoscaling" {
  desired_capacity          = 2
  max_size                  = 5
  min_size                  = 1
  health_check_type         = "ELB"
  health_check_grace_period = 300
  launch_configuration      = aws_launch_configuration.ec2.id
  vpc_zone_identifier       = aws_subnet.cba_public2.id

  target_group_arns = [aws_lb_target_group.alb-target-group.arn]

  tag {
    key                 = "Name"
    value               = "example-asg"
    propagate_at_launch = true
  }
}

data "aws_region" "current"{}





#Auto Scaling group; Launch template and Bastion Host in a Public subnet


data "aws_iam_policy_document" "ec2" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "session-manager" {
  description = "session-manager"
  name        = "session-manager"
  policy      = jsonencode({
    "Version":"2012-10-17",
    "Statement":[
      {
        "Action": "ec2:*",
        "Effect": "Allow",
        "Resource": "*"
      },
        {
            "Effect": "Allow",
            "Action": "elasticloadbalancing:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "cloudwatch:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "autoscaling:*",
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "iam:CreateServiceLinkedRole",
            "Resource": "*",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": [
                        "autoscaling.amazonaws.com",
                        "ec2scheduled.amazonaws.com",
                        "elasticloadbalancing.amazonaws.com",
                        "spot.amazonaws.com",
                        "spotfleet.amazonaws.com",
                        "transitgateway.amazonaws.com"
                    ]
                }
            }
        }
    ]
  })
}

resource "aws_iam_role" "session-manager" {
  assume_role_policy = data.aws_iam_policy_document.ec2.json
  name               = "session-manager"
  tags = {
    Name = "session-manager"
  }
}

resource "aws_iam_instance_profile" "session-manager" {
  name  = "session-manager"
  role  = aws_iam_role.session-manager.name
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.instance_ami.value
  instance_type               = "${var.instance_type}"
  key_name                    = aws_key_pair.terraform-lab.key_name
  iam_instance_profile        = aws_iam_instance_profile.session-manager.id
  associate_public_ip_address = true
  security_groups            = [aws_security_group.ec2.id]
  subnet_id                   = aws_subnet.public-subnet-1.id
  tags = {
    Name = "Bastion"
  }
}


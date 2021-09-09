terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "example-org-68bd7a"

    workspaces {
      name = "3tier"
    }
  }
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.5"
    }
  }

  required_version = ">= 1.0.5"
}

provider "aws" {
  region                  = "ap-northeast-2"     # Region
  shared_credentials_file = "~/.aws/credentials" # AWS Profile Path
}

# VPC

resource "aws_vpc" "vpc" {
  cidr_block       = "10.0.0.0/16"
  instance_tenancy = "default"
}

# Subnets

resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[0]
  availability_zone = data.aws_availability_zones.azs.names[0]
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[1]
  availability_zone = data.aws_availability_zones.azs.names[2]
}

resource "aws_subnet" "private_subnet_3" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[2]
  availability_zone = data.aws_availability_zones.azs.names[0]
}

resource "aws_subnet" "private_subnet_4" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.cidrs[3]
  availability_zone = data.aws_availability_zones.azs.names[2]
}

# Elastic IP
resource "aws_eip" "eip_ngw" {
  vpc = true
}

resource "aws_eip" "eip_bastion" {
  vpc      = true
  instance = aws_instance.bastion.id
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

# NAT Gateway
resource "aws_nat_gateway" "ngw" {
  allocation_id = aws_eip.eip_ngw.id
  subnet_id     = aws_subnet.public_subnet_2.id
  depends_on    = [aws_internet_gateway.igw]
}

# Route Tables

resource "aws_route_table" "route_table_public_igw" { # cidr: 0.0.0.0/0, target: igw
  vpc_id = aws_vpc.vpc.id

  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_internet_gateway.igw.id
    carrier_gateway_id         = null
    destination_prefix_list_id = null
    egress_only_gateway_id     = null
    instance_id                = null
    ipv6_cidr_block            = null
    local_gateway_id           = null
    nat_gateway_id             = null
    network_interface_id       = null
    transit_gateway_id         = null
    vpc_endpoint_id            = null
    vpc_peering_connection_id  = null
    }
  ]
}

resource "aws_route_table" "route_table_private_nat" {  # cidr: 0.0.0.0/0, target: nat
  vpc_id = aws_vpc.vpc.id

  route = [{
    cidr_block                 = "0.0.0.0/0"
    gateway_id                 = aws_nat_gateway.ngw.id
    carrier_gateway_id         = null
    destination_prefix_list_id = null
    egress_only_gateway_id     = null
    instance_id                = null
    ipv6_cidr_block            = null
    local_gateway_id           = null
    nat_gateway_id             = null
    network_interface_id       = null
    transit_gateway_id         = null
    vpc_endpoint_id            = null
    vpc_peering_connection_id  = null
  }]
}

resource "aws_route_table_association" "rt_associate_public_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.route_table_public_igw.id
}

resource "aws_route_table_association" "rt_associate_public_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.route_table_public_igw.id
}

resource "aws_route_table_association" "rt_associate_private_3" {
  subnet_id      = aws_subnet.private_subnet_3.id
  route_table_id = aws_route_table.route_table_private_nat.id
}

resource "aws_route_table_association" "rt_associate_private_4" {
  subnet_id      = aws_subnet.private_subnet_4.id
  route_table_id = aws_route_table.route_table_private_nat.id
}

# Network Interface
resource "aws_network_interface" "bastion" {
  subnet_id   = aws_subnet.public_subnet_1.id
  private_ips = ["10.0.0.10"]
}


# Instance

resource "aws_instance" "bastion" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance["Bastion"]
  key_name      = "bastion_key" # Key Pair

  network_interface {
    network_interface_id = aws_network_interface.bastion.id
    device_index         = 0
  }
}


# Security Group

resource "aws_security_group" "public_ssh_bastion" { # Bastion SG
  name   = "public_ssh_bastion"
  vpc_id = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "internet for bastion"
    from_port        = 22
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "tcp"
    security_groups  = null
    self             = false
    to_port          = 22
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "internet for bastion"
    from_port        = 0
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "-1"
    security_groups  = null
    self             = false
    to_port          = 0
  }]

}

resource "aws_security_group" "HTTP" { # Front-End Load Balancer SG
  name   = "access HTTP"
  vpc_id = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "access HTTP"
    from_port        = 80
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "tcp"
    security_groups  = null
    self             = false
    to_port          = 80
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "internet"
    from_port        = 0
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "-1"
    security_groups  = null
    self             = false
    to_port          = 0
  }]

}

resource "aws_security_group" "private_ssh" { # Private SSH SG
  name   = "private-ssh"
  vpc_id = aws_vpc.vpc.id

  ingress = [{
    cidr_blocks      = ["10.0.0.0/16"]
    description      = "ssh for private instance"
    from_port        = 22
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "tcp"
    security_groups  = null
    self             = false
    to_port          = 22
  }]

  egress = [{
    cidr_blocks      = ["0.0.0.0/0"]
    description      = "update for private istance"
    from_port        = 0
    ipv6_cidr_blocks = null
    prefix_list_ids  = null
    protocol         = "-1"
    security_groups  = null
    self             = false
    to_port          = 0
  }]

}


# Key Pair

resource "aws_key_pair" "kp_bastion" {
  key_name   = "bastion_key"
  public_key = file("../KP/bastion_key.pub") # Local Path
}

resource "aws_key_pair" "kp_front-end" {
  key_name   = "front-end_key"
  public_key = file("../KP/front-end_key.pub") # Local Path
}

resource "aws_key_pair" "kp_back-end" {
  key_name   = "back-end_key"
  public_key = file("../KP/back-end_key.pub") # Local Path
}


# Attach all

resource "aws_network_interface_sg_attachment" "bastion_sg_attachment" { # bastion - sg(ssh)
  security_group_id    = aws_security_group.public_ssh_bastion.id
  network_interface_id = aws_instance.bastion.primary_network_interface_id
}

# Autoscale Group

resource "aws_launch_template" "Front-End" { # Front-End Template
  name_prefix            = "Front-End_Template"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance["Front-End"]
  user_data              = base64encode(var.Front-End_instance_template) # user_data
  key_name               = var.Front-End_Key                             # Key Pair
  vpc_security_group_ids = ["${aws_security_group.HTTP.id}"]
}

resource "aws_autoscaling_group" "Front-End" { # Front-End ASG
  max_size = var.Front-End_ASG["MAX"]
  min_size = var.Front-End_ASG["MIN"]
  vpc_zone_identifier = [ # Autoscaling Subnet
    aws_subnet.private_subnet_3.id,
    aws_subnet.private_subnet_4.id
  ]

  health_check_grace_period = 300
  health_check_type         = "ELB"

  target_group_arns = ["${aws_lb_target_group.Front-End.arn}"]

  launch_template {
    id      = aws_launch_template.Front-End.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "Front-End" {   # ASG Front-End Policy
  name                   = "Front-End-ASG-Policy"
  autoscaling_group_name = aws_autoscaling_group.Front-End.name
  policy_type            = "TargetTrackingScaling"
  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = var.Back-End_ASG_Policy_AVGCPU
  }
}

resource "aws_launch_template" "Back-End" { # Back-End Template
  name_prefix            = "Back-End_Template"
  image_id               = data.aws_ami.ubuntu.id
  instance_type          = var.instance["Back-End"]
  user_data              = base64encode(var.Back-End_instance_template) # user_data
  key_name               = var.Back-End_Key                             # Key Pair
  vpc_security_group_ids = ["${aws_security_group.HTTP.id}"]
}

resource "aws_autoscaling_group" "Back-End" { # Back-End ASG
  max_size = var.Back-End_ASG["MAX"]
  min_size = var.Back-End_ASG["MIN"]
  vpc_zone_identifier = [ # Autoscaling Subnet
    aws_subnet.private_subnet_3.id,
    aws_subnet.private_subnet_4.id
  ]

  health_check_grace_period = 300
  health_check_type         = "ELB"

  target_group_arns = ["${aws_lb_target_group.Back-End.arn}"]

  launch_template {
    id      = aws_launch_template.Back-End.id
    version = "$Latest"
  }
}

resource "aws_autoscaling_policy" "Back-End" {  # ASG Back-End Policy
  name                      = "Back-End-ASG-Policy"
  autoscaling_group_name    = aws_autoscaling_group.Back-End.name
  policy_type               = "TargetTrackingScaling"
  estimated_instance_warmup = 200

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.Back-End_ASG_Policy_AVGCPU
  }
}

# Load Balancer

resource "aws_lb_target_group" "Front-End" { # Front-End Load Balancer
  name     = "Front-End-LB-TargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.vpc.id

}

resource "aws_lb" "Front-End" {
  name               = "Front-End-LB"
  load_balancer_type = "application"
  internal           = "false"
  security_groups    = [aws_security_group.HTTP.id]
  subnets = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id
  ]

  # access_logs {                                         # Access Log save as S3
  #   bucket = aws_s3_bucket.lb_logs.bucket
  #   prefix = "Front-End_Log"
  #   enabled = true
  # }
}

resource "aws_lb_listener" "Front-End" {
  load_balancer_arn = aws_lb.Front-End.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_lb_target_group.Front-End.id
    type             = "forward"
  }
}

resource "aws_lb_target_group" "Back-End" { # Back-End Load Balancer
  name     = "Back-End-LB-TargetGroup"
  port     = var.Back-End_Port
  protocol = "TCP"
  vpc_id   = aws_vpc.vpc.id
}

resource "aws_lb" "Back-End" {
  name               = "Back-End-LB"
  load_balancer_type = "network"
  internal           = "true"
  subnets = [
    aws_subnet.private_subnet_3.id,
    aws_subnet.private_subnet_4.id
  ]

  # access_logs {
  #   bucket = aws_s3_bucket.lb_logs.bucket
  #   prefix = "Front-End_Log"
  #   enabled = true
  # }
}

resource "aws_lb_listener" "Back-End" {
  load_balancer_arn = aws_lb.Back-End.arn
  port              = var.Back-End_Port
  protocol          = "TCP"

  default_action {
    target_group_arn = aws_lb_target_group.Back-End.id
    type             = "forward"
  }
}
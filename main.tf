# main.tf

terraform {
  backend "s3" {
    bucket = "terraform-state-gibok-2026"
    key    = "terraform/state.tfstate"
    region = "ap-northeast-2"
    encrypt = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 1. VPC & Subnet 조회
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "availability-zone"
    values = ["ap-northeast-2a", "ap-northeast-2c"]
  }
}

# 2. AMI 조회
data "aws_ami" "golden_image" {
  most_recent = true
  owners      = ["self"] 

  filter {
    name   = "name"
    values = ["golden-image-docker-*"] 
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 3. 보안 그룹
resource "aws_security_group" "ssh_allow" {
  name        = "allow_ssh_from_anywhere_asg"
  description = "Allow SSH inbound traffic for ASG"
  vpc_id      = data.aws_vpc.default.id

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
}

# 4. 시작 템플릿
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template-"
  image_id      = data.aws_ami.golden_image.id 
  instance_type = "t2.micro"
  key_name      = "terraform-key"

  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh_allow.id]
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ASG-Instance"
    }
  }
}

# 5. 오토 스케일링 그룹
resource "aws_autoscaling_group" "app_asg" {
  name                = "app-asg"
  desired_capacity    = 2
  max_size            = 3
  min_size            = 1
  
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ASG-Web-Server"
    propagate_at_launch = true
  }
}

# [추가됨] 6. 스케일링 정책 (Target Tracking)
# 목표: 평균 CPU 사용률을 30%로 유지해라. (넘으면 늘리고, 적으면 줄임)
resource "aws_autoscaling_policy" "target_tracking_cpu" {
  name                   = "target-tracking-cpu-30"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.app_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 30.0
  }
}

output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}
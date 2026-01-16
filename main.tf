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

# 1. VPC & Subnet 정보 조회 (ASG가 서버를 배치할 위치 파악)
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 2. AMI 조회: Amazon Linux가 아니라 "우리가 Packer로 만든 이미지"를 찾습니다.
data "aws_ami" "golden_image" {
  most_recent = true
  owners      = ["self"] # ★ 중요: 내 계정(Self)에서 찾기

  filter {
    name   = "name"
    values = ["golden-image-docker-*"] # Packer 설정 파일의 이름 규칙과 일치
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# 3. 보안 그룹 (기존과 동일)
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

# 4. 시작 템플릿 (Launch Template): "무엇을" 띄울 것인가?
# aws_instance 리소스 대신 이걸 사용합니다.
resource "aws_launch_template" "app_lt" {
  name_prefix   = "app-launch-template-"
  image_id      = data.aws_ami.golden_image.id # Packer로 만든 AMI 사용
  instance_type = "t2.micro"
  key_name      = "terraform-key"

  # 네트워크 설정
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.ssh_allow.id]
  }

  # 태그 설정
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ASG-Instance"
    }
  }
}

# 5. 오토 스케일링 그룹 (ASG): "어떻게, 얼마나" 띄울 것인가?
resource "aws_autoscaling_group" "app_asg" {
  name                = "app-asg"
  desired_capacity    = 2 # 평소에 2대 유지
  max_size            = 3 # 최대 3대까지 늘어남
  min_size            = 1 # 최소 1대는 무조건 유지
  
  # 위에서 조회한 Default VPC의 서브넷들에 골고루 배포
  vpc_zone_identifier = data.aws_subnets.default.ids

  launch_template {
    id      = aws_launch_template.app_lt.id
    version = "$Latest"
  }

  # 인스턴스 상태 확인 방식 (EC2 상태 기준)
  health_check_type         = "EC2"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "ASG-Web-Server"
    propagate_at_launch = true
  }
}

# 출력값: ASG는 IP가 유동적이므로, 그룹 이름만 출력해봅니다.
output "asg_name" {
  value = aws_autoscaling_group.app_asg.name
}
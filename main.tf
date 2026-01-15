# terraform 실습시작 xptmxm

terraform {
  backend "s3" {
    bucket = "terraform-state-gibok-2026"
    key = "terraform/state.tfstate"
    region = "ap-northeast-2"
    encrypt = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# [추가] AWS에서 최신 Amazon Linux 2 AMI 정보를 가져오는 데이터 소스
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    # amzn2-ami-hvm-*-x86_64-gp2 패턴의 이름을 가진 이미지 중 최신을 찾음
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ci-test-server" {
  # [수정] 위에서 찾은 최신 AMI의 ID를 자동으로 사용
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"

  # [추가] 1. 아까 AWS 콘솔에서 만든 키 페어 이름
  key_name = "terraform-key"

  tags = {
    Name = "CI-Test-Server"
  }
}

# [추가] 2. 서버가 다 만들어지면 IP 주소를 출력해라 (Ansible이 이걸 보고 접속함)
output "public_ip" {
  value = aws_instance.ci-test-server.public_ip
}
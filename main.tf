# main.tf

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

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# [추가 1] 보안 그룹 생성: SSH(22) 접속 허용
resource "aws_security_group" "ssh_allow" {
  name        = "allow_ssh_from_anywhere"
  description = "Allow SSH inbound traffic"

  # 들어오는 트래픽 (Ingress): 전 세계(0.0.0.0/0)에서 22번 포트 접속 허용
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # 나가는 트래픽 (Egress): 서버가 인터넷에서 뭘 다운로드 받을 수 있게 다 열어둠
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "ci-test-server" {
  ami           = data.aws_ami.amazon_linux_2.id
  instance_type = "t2.micro"
  key_name      = "terraform-key"

  # [추가 2] 위에서 만든 보안 그룹을 이 EC2에 장착!
  vpc_security_group_ids = [aws_security_group.ssh_allow.id]

  tags = {
    Name = "CI-Test-Server"
  }
}

output "public_ip" {
  value = aws_instance.ci-test-server.public_ip
}
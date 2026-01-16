packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    # Ansible 플러그인은 이제 필요 없지만, 혹시 모르니 남겨둬도 상관없습니다.
  }
}

source "amazon-ebs" "amazon_linux" {
  region          = "ap-northeast-2"
  ami_name        = "golden-image-docker-{{timestamp}}"
  instance_type   = "t2.micro"
  ssh_username    = "ec2-user"

  source_ami_filter {
    filters = {
      name                = "amzn2-ami-hvm-*-x86_64-gp2"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["amazon"]
  }
}

build {
  name = "learn-packer"
  sources = [
    "source.amazon-ebs.amazon_linux"
  ]

  # [대체 방안] Ansible 대신 Shell 스크립트로 직접 설치
  # 장점: SSH 연결 문제나 Python 버전 호환성 문제 없이 확실하게 동작함
  provisioner "shell" {
    inline = [
      # 1. 부팅 안정화 대기
      "sleep 30",
      
      # 2. 패키지 업데이트
      "sudo yum update -y",
      
      # 3. Docker 설치 (Amazon Linux Extras 사용)
      "sudo amazon-linux-extras install docker -y",
      
      # 4. Docker 실행 및 자동 시작 설정
      "sudo systemctl start docker",
      "sudo systemctl enable docker",
      
      # 5. 권한 설정 (ec2-user를 docker 그룹에 추가)
      "sudo usermod -aG docker ec2-user"
    ]
  }
}
packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/ansible"
    }
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

  # [수정됨] 충돌 나는 extras 대신, yum으로 안전하게 업데이트 및 pip 설치
  # sleep 30: 인스턴스 부팅 직후 네트워크/패키지 매니저가 안정화될 때까지 대기
  provisioner "shell" {
    inline = [
      "sleep 30",
      "sudo yum update -y",
      "sudo yum install -y python3-pip"
    ]
  }

  provisioner "ansible" {
    playbook_file = "./ansible/playbook.yml"
    
    extra_arguments = [ 
      "--extra-vars", "ansible_host_key_checking=False ansible_python_interpreter=/usr/bin/python3 ansible_scp_if_ssh=true",
      "--become" 
    ]
    user = "ec2-user"
    use_proxy = false
  }
}
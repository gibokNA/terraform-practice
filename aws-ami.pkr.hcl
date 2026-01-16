# aws-ami.pkr.hcl

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

  # Base Image 검색 (Terraform의 data "aws_ami"와 동일한 로직)
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

  # 기존 Ansible Playbook을 그대로 재사용합니다.
  provisioner "ansible" {
    playbook_file = "./ansible/playbook.yml"
    
    # Ansible 접속 시 호스트 키 확인을 건너뛰고, ec2-user 권한 사용 설정
    extra_arguments = [ 
      "--extra-vars", "ansible_host_key_checking=False",
      "--become" 
    ]
    user = "ec2-user"
    
    # 중요: Packer가 띄운 임시 서버와 로컬 Ansible 간의 통신 설정
    use_proxy = false
  }
}
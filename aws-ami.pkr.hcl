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

  # [추가됨] Ansible 실행 전에 Python 3를 먼저 설치합니다.
  # 이게 없으면 최신 Ansible이 Amazon Linux 2와 통신하다가 에러가 납니다.
  provisioner "shell" {
    inline = [
      "sudo amazon-linux-extras install python3 -y"
    ]
  }

  provisioner "ansible" {
    playbook_file = "./ansible/playbook.yml"
    
    # Python 3로 실행하도록 명시하고, SCP를 사용해 전송 오류 방지
    extra_arguments = [ 
      "--extra-vars", "ansible_host_key_checking=False ansible_python_interpreter=/usr/bin/python3 ansible_scp_if_ssh=true",
      "--become" 
    ]
    user = "ec2-user"
    use_proxy = false
  }
}
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

  provisioner "ansible" {
    playbook_file = "./ansible/playbook.yml"
    
    # [수정됨] 통신 안정성을 위한 옵션 추가 (Python3 지정, SCP 강제 사용)
    extra_arguments = [ 
      "--extra-vars", "ansible_host_key_checking=False ansible_python_interpreter=/usr/bin/python3 ansible_scp_if_ssh=true",
      "--become" 
    ]
    user = "ec2-user"
    use_proxy = false
  }
}
# terraform 실습시작

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

resource "aws_instance" "ci-test-server" {
  ami = "ami-0c9c942bd7bf113a2"
  instance_type = "t2.micro"

  tags = {
    Name = "CI-Test-Server"
  }
}
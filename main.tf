# main.tf

terraform {
  backend "s3" {
    bucket         = "terraform-state-gibok-2026"
    key            = "terraform/eks-state.tfstate"
    region         = "ap-northeast-2"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 1. VPC 모듈
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs            = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets = ["10.0.1.0/24", "10.0.2.0/24"]

  enable_nat_gateway      = false
  enable_vpn_gateway      = false
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

# 2. EKS 클러스터 모듈
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "my-practice-cluster"
  
  # [수정됨] 1.27 -> 1.30 (AWS 지원 버전으로 상향)
  cluster_version = "1.30"

  cluster_endpoint_public_access = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.public_subnets

  eks_managed_node_groups = {
    initial = {
      name = "node-group-1"
      instance_types = ["t3.medium"] 
      
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}
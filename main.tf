# main.tf

terraform {
  backend "s3" {
    bucket = "terraform-state-gibok-2026"  # 사용자님의 버킷 이름 유지
    key    = "terraform/eks-state.tfstate" # 키 경로를 살짝 변경해 겹침 방지
    region = "ap-northeast-2"
    encrypt = true
    dynamodb_table = "terraform-lock"
  }
}

provider "aws" {
  region = "ap-northeast-2"
}

# 1. VPC 모듈 (EKS 전용 네트워크 구성)
# NAT Gateway를 끄고 Public Subnet만 사용하여 비용을 아낍니다.
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "eks-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-northeast-2a", "ap-northeast-2c"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]

  # 비용 절약 설정 (NAT Gateway 미사용)
  enable_nat_gateway = false
  enable_vpn_gateway = false
  
  # 노드가 Public IP를 받아야 인터넷 통신 가능 (이미지 Pull 등)
  map_public_ip_on_launch = true

  # EKS 로드밸런서 생성을 위한 필수 태그
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }
}

# 2. EKS 클러스터 모듈
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.15.3"

  cluster_name    = "my-practice-cluster"
  cluster_version = "1.27"

  # 클러스터 접근 권한 설정 (Public)
  cluster_endpoint_public_access  = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.public_subnets

  # 관리형 노드 그룹 (워커 노드)
  eks_managed_node_groups = {
    initial = {
      name = "node-group-1"
      
      # t2.micro는 K8s 구동에 메모리가 부족하여 t3.small 권장
      instance_types = ["t3.small"] 
      
      min_size     = 1
      max_size     = 2
      desired_size = 1
    }
  }
}

# 출력값: 클러스터 접속에 필요한 정보
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-vpc"
  cidr = var.vpc_cidr

  azs             = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
  private_subnets = ["10.0.1.0/24",   "10.0.2.0/24"]

  enable_dns_support   = true
  enable_dns_hostnames = true

  enable_nat_gateway   = true
  single_nat_gateway   = true

  # Base tags for the VPC and all sub-resources
  tags = {
    Name        = "eks-vpc"
    Terraform   = "true"
    Environment = "dev"
  }

  public_subnet_tags = {
    "kubernetes.io/cluster/eks-max-project" = "shared"
    "kubernetes.io/role/elb"               = "1"
  }

  # Optionally, if you have internal ALBs:
  # private_subnet_tags = {
  #   "kubernetes.io/cluster/eks-max-project" = "shared"
  #   "kubernetes.io/role/internal-elb"       = "1"
  # }
}


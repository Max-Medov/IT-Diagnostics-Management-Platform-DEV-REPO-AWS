module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  bootstrap_self_managed_addons = true
#  cluster_addons = {
#    coredns                 = {}
#      addon_version               = "v1.11.4-eksbuild.1"
#      resolve_conflicts_on_create = "OVERWRITE"
#      resolve_conflicts_on_update = "OVERWRITE"    
#    eks-pod-identity-agent  = {}
#    kube-proxy              = {}
#    vpc-cni = {
#      addon_version               = "v1.19.2-eksbuild.1"
#      resolve_conflicts_on_create = "OVERWRITE"
#      resolve_conflicts_on_update = "OVERWRITE"
#    }
#  }

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.allowed_cidrs
  enable_cluster_creator_admin_permissions = true

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.private_subnets

  enable_irsa = true

  eks_managed_node_group_defaults = {
    instance_type = "t3.medium"
  }

  eks_managed_node_groups = {
    default = {
      ami_type       = "AL2023_x86_64_STANDARD"
      instance_types = ["t3.medium"]
      min_size       = 1
      desired_size   = 2
      max_size       = 3

      key_name = "MyKeyPair"
    }
  }

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}


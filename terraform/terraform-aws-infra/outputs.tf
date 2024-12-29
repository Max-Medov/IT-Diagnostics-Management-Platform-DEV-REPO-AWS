data "aws_eks_cluster" "kubeconfig" {
  name       = module.eks.cluster_name
  depends_on = [module.eks] 
}

data "aws_eks_cluster_auth" "kubeconfig" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

output "cluster_name" {
  description = "The EKS cluster name"
  value       = module.eks.cluster_name
}

output "kubeconfig" {
  description = "Kubeconfig for connecting to the EKS cluster"
  sensitive   = true

  value = <<EOT
apiVersion: v1
clusters:
- cluster:
    server: ${data.aws_eks_cluster.kubeconfig.endpoint}
    certificate-authority-data: ${data.aws_eks_cluster.kubeconfig.certificate_authority[0].data}
  name: ${data.aws_eks_cluster.kubeconfig.name}
contexts:
- context:
    cluster: ${data.aws_eks_cluster.kubeconfig.name}
    user: ${data.aws_eks_cluster.kubeconfig.name}
  name: ${data.aws_eks_cluster.kubeconfig.name}
current-context: ${data.aws_eks_cluster.kubeconfig.name}
kind: Config
preferences: {}
users:
- name: ${data.aws_eks_cluster.kubeconfig.name}
  user:
    token: ${data.aws_eks_cluster_auth.kubeconfig.token}
EOT
}


variable "cluster_name" {
  type    = string
  default = "eks-max-project"
}

variable "cluster_version" {
  type    = string
  default = "1.31"
}

variable "allowed_cidrs" {
  type    = list(string)
  # Restrict the public EKS API to my IP
  default = ["87.71.165.114/32"]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}


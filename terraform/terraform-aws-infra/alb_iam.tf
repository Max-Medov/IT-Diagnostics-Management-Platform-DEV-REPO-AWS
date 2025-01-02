locals {
  splitted_oidc = split("oidc-provider/", module.eks.oidc_provider_arn)
  oidc_url = local.splitted_oidc[1] # e.g. "oidc.eks.us-east-1.amazonaws.com/id/<OIDC_ID>"
}

# Create the trust policy so the ALB Controller Pod can assume this role
data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      # e.g. "oidc.eks.us-east-1.amazonaws.com/id/<OIDC_ID>:sub"
      variable = "${local.oidc_url}:sub"
      values = [
        # Must match your ServiceAccount's "namespace:name"
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

# Create the IAM Role with the above trust policy
resource "aws_iam_role" "alb_controller" {
  name               = "alb-controller-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

# Use the AWS managed AdministratorAccess policy
data "aws_iam_policy" "administrator_access" {
  arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# Attach the AdministratorAccess policy to the IAM role
resource "aws_iam_role_policy_attachment" "alb_controller_admin_policy_attach" {
  policy_arn = data.aws_iam_policy.administrator_access.arn
  role       = aws_iam_role.alb_controller.name
}

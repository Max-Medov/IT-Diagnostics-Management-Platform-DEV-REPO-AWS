locals {
  splitted_oidc = split("oidc-provider/", module.eks.oidc_provider_arn)
  oidc_url = local.splitted_oidc[1]
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    condition {
      test     = "StringEquals"
      # This yields something like:
      #   "oidc.eks.us-east-1.amazonaws.com/id/<UNIQUE_ID>:sub"
      variable = "${local.oidc_url}:sub"

      values = [
        # Must match your serviceAccount's namespace/name
        "system:serviceaccount:kube-system:aws-load-balancer-controller"
      ]
    }
  }
}

resource "aws_iam_role" "alb_controller" {
  name               = "alb-controller-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

resource "aws_iam_role_policy_attachment" "alb_controller_elb_fullaccess" {
  policy_arn = "arn:aws:iam::aws:policy/ElasticLoadBalancingFullAccess"
  role       = aws_iam_role.alb_controller.name
}


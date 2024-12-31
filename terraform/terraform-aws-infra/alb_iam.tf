locals {
  splitted_oidc = split("oidc-provider/", module.eks.oidc_provider_arn)
  oidc_url = local.splitted_oidc[1] # e.g. "oidc.eks.us-east-1.amazonaws.com/id/<OIDC_ID>"
}

# 2) Create the trust policy so the ALB Controller Pod can assume this role
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

# 3) Create the IAM Role with the above trust policy
resource "aws_iam_role" "alb_controller" {
  name               = "alb-controller-irsa-role"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json

  tags = {
    Environment = "dev"
    Terraform   = "true"
  }
}

data "aws_iam_policy_document" "alb_controller_official_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeAccountAttributes",
      "ec2:DescribeAddresses",
      "ec2:DescribeAvailabilityZones",
      "ec2:DescribeInternetGateways",
      "ec2:DescribeRouteTables",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "elasticloadbalancing:*",
    ]
    resources = ["*"]
  }

}

# 5) Create a policy from the above JSON
resource "aws_iam_policy" "alb_controller_custom_policy" {
  name   = "alb-controller-custom-policy"
  policy = data.aws_iam_policy_document.alb_controller_official_policy.json
}

# 6) Attach the custom policy to our role
resource "aws_iam_role_policy_attachment" "alb_controller_custom_attach" {
  policy_arn = aws_iam_policy.alb_controller_custom_policy.arn
  role       = aws_iam_role.alb_controller.name
}




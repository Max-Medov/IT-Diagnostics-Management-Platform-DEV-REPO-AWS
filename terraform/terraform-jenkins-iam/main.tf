provider "aws" {
  region  = var.aws_region
  profile = "default" 
}

resource "aws_iam_user" "jenkins_user" {
  name = var.jenkins_user_name

  tags = {
    Name        = var.jenkins_user_name
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_iam_policy" "jenkins_terraform_policy" {
  name        = "jenkins-terraform-policy"
  description = "Policy for Terraform to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "*",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "jenkins_policy_attachment" {
  user       = aws_iam_user.jenkins_user.name
  policy_arn = aws_iam_policy.jenkins_terraform_policy.arn
}

resource "aws_iam_access_key" "jenkins_access_key" {
  user = aws_iam_user.jenkins_user.name
}


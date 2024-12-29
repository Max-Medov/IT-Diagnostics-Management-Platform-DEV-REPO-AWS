variable "aws_region" {
  description = "AWS region to deploy resources"
  default     = "us-east-1"
}

variable "jenkins_user_name" {
  description = "Name of the Jenkins IAM user"
  default     = "jenkins-user"
}

variable "key_pair_name" {
  description = "Name of the AWS EC2 Key Pair"
  default     = "terraform-jenkins-keypair" 
}


output "jenkins_access_key_id" {
  value       = aws_iam_access_key.jenkins_access_key.id
  description = "Access Key ID for Jenkins IAM user"
  sensitive   = true
}

output "jenkins_secret_access_key" {
  value       = aws_iam_access_key.jenkins_access_key.secret
  description = "Secret Access Key for Jenkins IAM user"
  sensitive   = true
}


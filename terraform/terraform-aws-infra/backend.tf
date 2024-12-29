terraform {
  backend "s3" {
    bucket         = "max-terraform-state-bucket"  # Replace with your bucket name
    key            = "eks/terraform.tfstate"       # Path to store the state file
    region         = "us-east-1"                   # AWS region
    encrypt        = true                          # Enable encryption for security
  }
}


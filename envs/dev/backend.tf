# Terraform Backend Configuration for Dev Environment
# Auto-configured by deploy-all.sh

terraform {
  backend "s3" {
    bucket         = "leasebase-tfstate-dev-335021149718-v2"
    key            = "envs/dev/terraform.tfstate"
    region         = "us-west-1"
    dynamodb_table = "terraform-locks-dev"
    encrypt        = true
  }
}

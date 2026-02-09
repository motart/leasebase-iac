# Terraform Backend Configuration for QA Environment
#
# Before using remote state:
# 1. Run: scripts/bootstrap_remote_state.sh --profile iamadmin-master --region us-east-1 --env qa
# 2. Update the bucket and dynamodb_table values below with the output from step 1
# 3. Run: terraform init -migrate-state

terraform {
  backend "s3" {
    # Uncomment and configure after running bootstrap_remote_state.sh
    # bucket         = "leasebase-tfstate-qa-ACCOUNT_ID"
    # key            = "envs/qa/terraform.tfstate"
    # region         = "us-east-1"
    # dynamodb_table = "terraform-locks-qa"
    # encrypt        = true
  }
}

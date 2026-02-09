# Terraform Backend Configuration for UAT Environment
#
# Before using remote state:
# 1. Run: scripts/bootstrap_remote_state.sh --profile iamadmin-master --region us-west-1 --env uat
# 2. Update the bucket and dynamodb_table values below with the output from step 1
# 3. Run: terraform init -migrate-state

terraform {
  backend "s3" {
    # Uncomment and configure after running bootstrap_remote_state.sh
    # bucket         = "leasebase-tfstate-uat-ACCOUNT_ID"
    # key            = "envs/uat/terraform.tfstate"
    # region         = "us-west-1"
    # dynamodb_table = "terraform-locks-uat"
    # encrypt        = true
  }
}

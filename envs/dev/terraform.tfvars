aws_region = "us-west-2"

# VPC
vpc_cidr           = "10.110.0.0/16"
az_count           = 2
enable_nat_gateway = true
single_nat_gateway = true

# TLS
acm_certificate_arn            = ""
cloudfront_acm_certificate_arn = "arn:aws:acm:us-east-1:335021149718:certificate/ba52f13c-c3ce-43db-9e6d-34aaed6abffc"

# Domain
domain_name             = "app.dev.leasebase.ai"
api_domain_name         = "api.dev.leasebase.ai"
root_domain_name        = "leasebase.ai"
env_subdomain_prefix    = "dev"
old_root_domain_name    = "leasebase.co"
vanity_redirect_domains = ["signin.dev.leasebase.ai", "signup.dev.leasebase.ai"]

# ── Cutover control ──────────────────────────────────────────────────────────
# Step 1 (initial apply): enable_cloudfront = true, route53_web_target = "cloudfront"
#   Creates ACM cert, HTTPS listener, API GW custom domain. CloudFront stays.
# Step 2 (after verification): route53_web_target = "alb"
#   Switches Route53 to web ALB. Validate HTTPS + API endpoints.
# Step 3 (cleanup): enable_cloudfront = false
#   Destroys CloudFront distribution.
enable_cloudfront  = false
route53_web_target = "alb"

# ECS
log_retention_days = 7

# Aurora Serverless v2
db_name             = "leasebase"
aurora_min_capacity = 0.5
aurora_max_capacity = 4

# Redis
redis_node_type = "cache.t3.micro"

# Feature flags (cost saving: disabled in dev)
enable_opensearch     = false
enable_waf            = false
enable_lambda_workers = false

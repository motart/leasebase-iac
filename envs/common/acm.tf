############################
# ACM Certificate for HTTPS
############################

# Request ACM certificate for the environment subdomain
resource "aws_acm_certificate" "subdomain" {
  count             = var.create_dns_record ? 1 : 0
  domain_name       = "${var.environment}.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${local.name_prefix}-cert"
    Environment = var.environment
    Project     = "leasebase"
  }
}

# Create Route 53 validation record for ACM certificate
resource "aws_route53_record" "cert_validation" {
  for_each = var.create_dns_record ? {
    for dvo in aws_acm_certificate.subdomain[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  } : {}

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = var.route53_zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "subdomain" {
  count                   = var.create_dns_record ? 1 : 0
  certificate_arn         = aws_acm_certificate.subdomain[0].arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

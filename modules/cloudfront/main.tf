################################################################################
# CloudFront Module - LeaseBase v2
# Distribution fronting API Gateway
#
# Cache strategy:
#   /_next/static/*  — immutable, content-hashed; cached aggressively (1yr)
#   everything else  — no CloudFront cache; always forwarded to origin
#
# Security response headers (HSTS, nosniff, etc.) applied to all behaviors.
################################################################################

# ── Managed cache policies ───────────────────────────────────────────────────

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

# ── Security response headers ────────────────────────────────────────────────

resource "aws_cloudfront_response_headers_policy" "security" {
  name    = "${var.name_prefix}-security-headers"
  comment = "Security response headers for ${var.name_prefix}"

  security_headers_config {
    strict_transport_security {
      access_control_max_age_sec = 63072000 # 2 years
      include_subdomains         = true
      preload                    = true
      override                   = true
    }
    content_type_options {
      override = true
    }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    xss_protection {
      mode_block = false
      protection = false
      override   = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
  }
}

# ── Distribution ─────────────────────────────────────────────────────────────

resource "aws_cloudfront_distribution" "main" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "LeaseBase ${var.environment} v2"
  default_root_object = ""
  price_class         = var.price_class
  aliases             = var.domain_aliases
  web_acl_id          = var.web_acl_arn

  # API Gateway origin
  origin {
    domain_name = replace(var.api_gateway_endpoint, "https://", "")
    origin_id   = "apigw"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Next.js immutable static assets (/_next/static/*) ──────────────────────
  # These are content-hashed and never change; cache for the maximum duration.
  ordered_cache_behavior {
    path_pattern     = "/_next/static/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "apigw"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_optimized.id
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  # ── Default behavior (HTML, API, everything else) ──────────────────────────
  # No CloudFront caching — prevents stale HTML after deploys.
  # Origin may send s-maxage, but CachingDisabled forces TTL=0 at the edge.
  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "apigw"

    cache_policy_id            = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                   = true
    viewer_protocol_policy     = "redirect-to-https"
    response_headers_policy_id = aws_cloudfront_response_headers_policy.security.id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == ""
    acm_certificate_arn            = var.acm_certificate_arn != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.acm_certificate_arn != "" ? "sni-only" : null
    minimum_protocol_version       = var.acm_certificate_arn != "" ? "TLSv1.2_2021" : null
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cdn"
  })
}

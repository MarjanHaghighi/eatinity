resource "aws_cloudfront_origin_access_control" "website" {
  name                              = "${var.resource_prefix}-website-oac"
  description                       = "OAC for ${var.resource_prefix} website"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.resource_prefix} frontend"
  aliases             = var.use_custom_domain ? [var.domain_name, "www.${var.domain_name}"] : []

  origin {
    domain_name              = var.website_bucket.domain
    origin_id                = "s3-${var.website_bucket.name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.website.id
  }
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-${var.website_bucket.name}"
    viewer_protocol_policy = "redirect-to-https"
    compress               = true
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }
  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    acm_certificate_arn            = var.use_custom_domain ? var.acm_certificate_arn : null
    cloudfront_default_certificate = !var.use_custom_domain
    ssl_support_method             = var.use_custom_domain ? "sni-only" : null
    minimum_protocol_version       = var.use_custom_domain ? "TLSv1.2_2021" : "TLSv1"
  }
  tags = var.tags
}

resource "aws_s3_bucket_policy" "website" {
  bucket = var.website_bucket.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid = "AllowCloudFrontRead", Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = "s3:GetObject", Resource = "${var.website_bucket.arn}/*", Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.website.arn } }
    }]
  })
}

data "aws_route53_zone" "this" {
  count        = var.manage_public_dns ? 1 : 0
  name         = var.domain_name
  private_zone = false
}

resource "aws_route53_record" "root" {
  count   = var.manage_public_dns ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www" {
  count   = var.manage_public_dns ? 1 : 0
  zone_id = data.aws_route53_zone.this[0].zone_id
  name    = "www.${var.domain_name}"
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}

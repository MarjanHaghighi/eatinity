resource "aws_cloudfront_distribution" "eatinity_cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront distribution for Eatinity frontend"
  default_root_object = "index.html"

  aliases = [
    var.domain_name,
    var.www_domain_name
  ]

  origin {
    domain_name              = "${var.website_bucket_name}.s3.amazonaws.com"
    origin_id                = "${var.website_bucket_name}.s3.amazonaws.com-mqbg0l01z9k"
    origin_access_control_id = "E28NJWZUA8YWZP"
  }

  default_cache_behavior {
    target_origin_id       = "${var.website_bucket_name}.s3.amazonaws.com-mqbg0l01z9k"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    compress        = true
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate.eatinity_cert.arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Name = "eatinity-prod-cdn"
  }
}
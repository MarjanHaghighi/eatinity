resource "aws_route53_zone" "eatinity_zone" {
  name = var.domain_name
  comment       = ""
  force_destroy = false
}

# Route 53 A records to CloudFront

resource "aws_route53_record" "root_alias" {
  zone_id = aws_route53_zone.eatinity_zone.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.eatinity_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.eatinity_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www_alias" {
  zone_id = aws_route53_zone.eatinity_zone.zone_id
  name    = var.www_domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.eatinity_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.eatinity_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}


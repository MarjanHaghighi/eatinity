output "products_api_url" {
  value = "${aws_apigatewayv2_api.api.api_endpoint}/products"
}

output "images_bucket_name" {
  value = aws_s3_bucket.images.bucket
}

output "website_bucket_name" {
  value = aws_s3_bucket.website.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.products.name
}

output "route53_nameservers" {
  value = aws_route53_zone.eatinity_zone.name_servers
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.eatinity_cdn.domain_name
}

output "website_url" {
  value = "https://${var.domain_name}"
}

output "www_website_url" {
  value = "https://${var.www_domain_name}"
}

output "image_base_url" {
  value = "https://${var.images_bucket_name}.s3.${var.aws_region}.amazonaws.com/"
}
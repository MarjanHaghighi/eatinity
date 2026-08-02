output "website" { value = { id = aws_s3_bucket.website.id, arn = aws_s3_bucket.website.arn, domain = aws_s3_bucket.website.bucket_regional_domain_name, name = aws_s3_bucket.website.bucket } }
output "images" { value = { id = aws_s3_bucket.images.id, arn = aws_s3_bucket.images.arn, domain = aws_s3_bucket.images.bucket_regional_domain_name, name = aws_s3_bucket.images.bucket } }

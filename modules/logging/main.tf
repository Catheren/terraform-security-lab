resource "aws_s3_bucket" "trail_bucket" {
  bucket = var.bucket_name
}
resource "aws_cloudtrail" "this" {
  name           = "security-trail"
  s3_bucket_name = aws_s3_bucket.trail_bucket.id

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
}

resource "aws_s3_bucket_policy" "trail_policy" {
  bucket = aws_s3_bucket.trail_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AWSCloudTrailAclCheck"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.trail_bucket.arn
      },
      {
        Sid    = "AWSCloudTrailWrite"
        Effect = "Allow"
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.trail_bucket.arn}/*"

        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}
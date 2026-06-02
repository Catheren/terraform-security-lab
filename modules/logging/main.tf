resource "aws_s3_bucket" "trail_bucket" {
  bucket = var.bucket_name

  tags = {
    Environment        = var.environment
    Owner              = "security-team"
    Project            = "security-lab"
    DataClassification = "internal"
  }
}
resource "aws_cloudtrail" "this" {
  name           = "security-trail"
  s3_bucket_name = aws_s3_bucket.trail_bucket.id

  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  enable_log_file_validation    = true
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

# Lifecycle policy for CloudTrail logs.
# Transitions logs to cheaper storage after 90 days,
# expires them after 365 days to control costs and
# meet data retention compliance requirements.
resource "aws_s3_bucket_lifecycle_configuration" "trail_bucket" {
  bucket = aws_s3_bucket.trail_bucket.id

  rule {
    id     = "cloudtrail-log-retention"
    status = "Enabled"

    transition {
      days          = 90
      storage_class = "STANDARD_IA" # cheaper storage after 90 days
    }

    expiration {
      days = 365 # delete after 1 year
    }
  }
}
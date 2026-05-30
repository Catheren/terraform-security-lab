variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "trail_bucket_name" {
  description = "Name of the CloudTrail logging bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}
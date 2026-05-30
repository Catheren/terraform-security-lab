output "instance_profile_name" {
  value = aws_iam_instance_profile.this.name
}


variable "role_name" {
  type        = string
  description = "Name of the IAM role for EC2"
}
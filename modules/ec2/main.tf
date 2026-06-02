resource "aws_instance" "this" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id

  iam_instance_profile = var.instance_profile_name
  monitoring           = true # 1-minute CloudWatch metrics vs default 5-minute
  ebs_optimized        = true # dedicated bandwidth between instance and EBS

  # Enforce IMDSv2 — prevents SSRF attacks from stealing
  # IAM credentials via the metadata endpoint.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Encrypt the root EBS volume at rest.
  # Protects data if the underlying hardware is compromised.
  root_block_device {
    encrypted = true
  }

  tags = {
    Name               = var.instance_name
    Environment        = var.environment
    Owner              = "security-team"
    Project            = "security-lab"
    DataClassification = "internal"
  }

}
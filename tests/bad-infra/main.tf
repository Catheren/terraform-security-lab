# =============================================================
# INTENTIONALLY INSECURE TERRAFORM
# =============================================================
# This file simulates common security misconfigurations to
# demonstrate that the CI/CD pipeline detects and blocks them.
#
# DO NOT apply this to any AWS environment.
# This file exists purely for pipeline testing purposes.
#
# Vulnerabilities demonstrated:
#   1. Public S3 bucket — data exposed to internet
#   2. Unrestricted SSH — port 22 open to 0.0.0.0/0
#   3. Wildcard IAM policy — full account permissions
# =============================================================

# ── VULNERABILITY 1
# block_public_acls = false allows public ACLs on objects.
# block_public_policy = false allows public bucket policies.
# Any data stored here is readable by the entire internet.
# Detected by: tfsec, Checkov, custom scanner (S3-001)
resource "aws_s3_bucket" "insecure_bucket" {
  bucket = "company-customer-data-insecure"
}

resource "aws_s3_bucket_public_access_block" "insecure_bucket" {
  bucket = aws_s3_bucket.insecure_bucket.id

  block_public_acls       = false # ← BAD: allows public ACLs
  block_public_policy     = false # ← BAD: allows public policies
  ignore_public_acls      = false # ← BAD: does not ignore public ACLs
  restrict_public_buckets = false # ← BAD: bucket is publicly accessible
}

# ── VULNERABILITY 2: Unrestricted SSH ─────────────────────
# cidr_blocks = ["0.0.0.0/0"] on port 22 allows SSH access
# from any IP address on the internet.
# Attackers can brute-force credentials or exploit SSH vulnerabilities.
# Detected by: tfsec, Checkov
resource "aws_security_group" "insecure_sg" {
  name        = "insecure-sg"
  description = "Insecure security group for pipeline testing"
  vpc_id      = "vpc-00000000"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ← BAD: SSH open to entire internet
    description = "SSH from anywhere"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
}

# ── VULNERABILITY 3: Wildcard IAM Policy ──────────────────
# actions = ["*"] grants every possible AWS API action.
# resource = "*" applies it to every resource in the account.
# If this role is compromised, the attacker has full control
# of the entire AWS account — create, delete, exfiltrate anything.
# Detected by: tfsec, Checkov, custom scanner (IAM rules)
resource "aws_iam_policy" "insecure_policy" {
  name        = "insecure-wildcard-policy"
  description = "Wildcard policy for pipeline testing — DO NOT USE"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["*"] # ← BAD: grants all AWS actions
      Resource = "*"   # ← BAD: applies to all resources
    }]
  })
}
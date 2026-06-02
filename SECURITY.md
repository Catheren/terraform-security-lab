# Security Controls & Remediation Guide

This repository enforces security, compliance, and quality controls
on every pull request through an automated CI/CD pipeline.
All findings are either remediated or documented with justification.

---

## CI/CD Pipeline

Every PR triggers the following jobs automatically.
A failed job blocks the PR from merging.

| Job | Tool | What it checks |
|-----|------|----------------|
| Terraform Format & Validate | terraform fmt / validate | Syntax and formatting |
| IaC Security Scan | tfsec | Terraform misconfigurations |
| Policy Compliance Scan | Checkov | CIS, SOC2, PCI-DSS controls |
| Secret Detection | Gitleaks | Credentials in git history |
| Custom Policy Scanner | scanner.py | Org-specific standards |

---

## Findings Remediated

### CKV_AWS_36 — CloudTrail log file validation
**File:** modules/logging/main.tf  
**Risk:** Without validation, tampered log files are undetectable.
Attackers who modify logs after delivery can erase evidence of
their activity. Log file validation creates a hash digest of every
log — any modification is immediately detectable.  
**Fix:** Added `enable_log_file_validation = true` to aws_cloudtrail.

---

### CKV2_AWS_61 — S3 bucket missing lifecycle policy
**File:** modules/logging/main.tf  
**Risk:** Without a lifecycle policy, logs accumulate indefinitely.
This increases storage costs and retains sensitive audit data beyond
what compliance frameworks allow.  
**Fix:** Added aws_s3_bucket_lifecycle_configuration — transitions
logs to STANDARD_IA after 90 days, expires after 365 days.

---

### CKV_AWS_79 — IMDSv1 enabled on EC2
**File:** modules/ec2/main.tf  
**Risk:** IMDSv1 allows any process on the instance to retrieve IAM
credentials via a simple HTTP GET to 169.254.169.254. This is the
primary attack path in Server Side Request Forgery (SSRF) attacks.  
**Fix:** Added metadata_options block enforcing http_tokens = required
(IMDSv2 only). IMDSv2 requires a session token, blocking SSRF.

---

### CKV_AWS_8 — EBS volume not encrypted
**File:** modules/ec2/main.tf  
**Risk:** Unencrypted EBS volumes expose data if the underlying
hardware is decommissioned or physically compromised.  
**Fix:** Added root_block_device block with encrypted = true.

---

### CKV_AWS_126 — EC2 detailed monitoring disabled
**File:** modules/ec2/main.tf  
**Risk:** Default 5-minute metrics delay anomaly detection.
In a security incident, 5 minutes of undetected activity can mean
significant damage.  
**Fix:** Added monitoring = true for 1-minute CloudWatch metrics.

---

### CKV_AWS_135 — EC2 not EBS optimized
**File:** modules/ec2/main.tf  
**Risk:** Without EBS optimization, storage I/O competes with network
traffic causing unpredictable performance under load.  
**Fix:** Added ebs_optimized = true.

---

### CKV_AWS_130 — Subnet assigns public IPs by default
**File:** modules/vpc/main.tf  
**Risk:** Every instance launched in this subnet automatically receives
a public IP, making it directly reachable from the internet regardless
of intent.  
**Fix:** Changed map_public_ip_on_launch to false. Public IPs must now
be assigned explicitly.

---

### CKV2_AWS_12 — Default VPC security group allows traffic
**File:** modules/vpc/main.tf  
**Risk:** The default security group allows all traffic between
resources that share it. Resources launched without an explicit
security group land here, creating unintended exposure.  
**Fix:** Added aws_default_security_group resource with no ingress
or egress rules — deny all by default.

---

## Accepted Risks

The following findings are documented as accepted risks for this
environment with justification.

### CKV_AWS_35 — CloudTrail KMS encryption
**Status:** Accepted risk  
**Justification:** KMS keys incur $1/month per key. This is a
non-production lab environment. S3 server-side encryption (AES256)
provides encryption at rest. KMS CMK encryption will be enforced
in production environments.

---

### CKV_AWS_252 — CloudTrail SNS notification
**Status:** Accepted risk  
**Justification:** SNS notifications require additional infrastructure
(topic, subscription, endpoint). Out of scope for this lab environment.
In production, CloudTrail SNS integration feeds the SIEM for real-time
log ingestion alerting.

---

## Custom Scanner Policy (scanner.py)

The custom scanner enforces organization-specific standards that
generic tools cannot know about.

| Rule | Severity | Policy |
|------|----------|--------|
| TAG-001 | HIGH | All AWS resources must have: Environment, Owner, Project, DataClassification tags |
| NAME-001 | MEDIUM | Resources must follow naming convention: {project}-{env}-{purpose} |
| RGN-001 | HIGH | Deployments only permitted in us-east-1 and us-west-2 |
| ACCT-001 | CRITICAL | AWS account IDs must use var.aws_account_id — no hardcoded values |
| S3-001 | MEDIUM | All S3 buckets must have aws_s3_bucket_logging configured |

### Why these rules exist

**Tagging** — enables cost attribution by business unit, identifies
resource ownership during incident response, and supports data
classification for compliance reporting.

**Naming conventions** — enforces operational consistency and enables
scripted automation against predictable resource names.

**Region restrictions** — enforces compliance boundary control under
applicable data residency regulations. Resources outside approved
regions fall outside monitored security controls.

**No hardcoded account IDs** — reduces attack surface by keeping
account identifiers out of source code. Enables account portability
for disaster recovery scenarios.

**S3 logging** — ensures audit trail exists for all bucket access.
Required for incident response — without access logs, answering
"who accessed this data?" is impossible.
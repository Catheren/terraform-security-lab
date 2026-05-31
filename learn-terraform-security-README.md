# Terraform Security Engineering — Study & Reference Notes

> **Purpose:** Interview prep and reference guide for Terraform security concepts at an intermediate level.  
> Focus: The 20% of concepts that come up in 80% of security engineering interviews.

---

## Table of Contents

1. [Core Mental Model](#core-mental-model)
2. [Terraform Fundamentals](#terraform-fundamentals)
3. [IAM Least Privilege](#iam-least-privilege)
4. [Secure-by-Default Templates](#secure-by-default-templates)
5. [Drift Detection](#drift-detection)
6. [Guardrails & Enforcement](#guardrails--enforcement)
7. [Terraform State Security](#terraform-state-security)
8. [Common Attack Paths](#common-attack-paths)
9. [Interview Framework](#interview-framework)

---

## Core Mental Model

Terraform security rests on four pillars. Every concept below maps to one of these:

| Pillar | Goal | Primary Tools |
|---|---|---|
| **Secure by Default** | Prevent misconfiguration before it ships | Modules, policy-as-code |
| **Least Privilege IAM** | Limit blast radius when something goes wrong | IAM policies, SCPs, permission boundaries |
| **Visibility** | Know what changed, when, and by whom | CloudTrail, AWS Config, SIEM |
| **Enforcement** | Make insecure infrastructure hard or impossible to deploy | Guardrails, CI/CD gates, auto-remediation |

---

## Terraform Fundamentals

### Core Workflow

```
Write Code → terraform init → terraform plan → terraform apply
```

| Command | What it Does | Security Note |
|---|---|---|
| `terraform init` | Downloads providers, initializes backend | Backend config determines state security |
| `terraform plan` | Shows proposed changes — no changes made | Use in CI/CD to review before apply |
| `terraform apply` | Executes changes against real infrastructure | Should require approval in production |

### Key Blocks

```hcl
# Provider — defines the cloud platform
provider "aws" {
  region = "us-east-1"
}

# Resource — actual infrastructure
resource "aws_s3_bucket" "logs" {
  bucket = "app-logs-prod"
}

# Variable — avoids hardcoding sensitive values
variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket"
}

# Output — exposes values to other modules/pipelines
output "bucket_arn" {
  value = aws_s3_bucket.logs.arn
}
```

**Why IaC matters for security:**
- Infrastructure changes go through version control and peer review
- Repeatable, auditable deployments replace ad-hoc console clicks
- Drift between code and reality becomes detectable

---

## IAM Least Privilege

### The Core Principle

Grant the *minimum* permissions required to perform a task — nothing more.

### High-Risk Pattern to Recognize Immediately

```json
{
  "Effect": "Allow",
  "Action": "*",
  "Resource": "*"
}
```

This is full account access. In an interview, calling this out instantly signals security awareness.

### IAM Review Checklist (Use This in Interviews)

When reviewing any IAM policy, ask:

1. **Who** — Which identity (user, role, service) gets this?
2. **What** — Which actions are permitted?
3. **Where** — Which specific resources?
4. **Why** — Is there a business justification?

### Privilege Escalation via Permission Chaining

Individual permissions can look harmless. Combined, they create escalation paths.

**Example dangerous chain:**

```
iam:PassRole + lambda:CreateFunction + lambda:InvokeFunction
```

An attacker with these three permissions can:
1. Create a Lambda function
2. Attach a high-privilege role to it via `PassRole`
3. Invoke the function → execute code under elevated permissions

**Other permissions that enable escalation:**

```
iam:CreateUser
iam:AttachUserPolicy
iam:PutUserPolicy
```

**Interview line:** *"IAM risks aren't individual permissions — they're combinations that form escalation paths."*

### Best Practices

- Avoid wildcards in `Action` and `Resource`
- Prefer roles over long-lived IAM users
- Use permission boundaries to cap maximum privilege
- Remove unused permissions on a regular schedule

---

## Secure-by-Default Templates

### The Problem

Developers shouldn't have to know every security configuration. Modules enforce security by removing the option to skip it.

### Common Misconfigurations (Know These)

| Misconfiguration | Risk |
|---|---|
| Public S3 bucket | Data exposure |
| Encryption disabled | Undetected exfiltration |
| Logging disabled | No forensic trail |
| Open security group (`0.0.0.0/0`) | Network exposure |
| Database in public subnet | Direct attack surface |

### Secure S3 Module Pattern

Instead of:

```hcl
resource "aws_s3_bucket" "data" {
  bucket = "my-bucket"
}
```

Use a module that enforces:

```hcl
module "secure_bucket" {
  source      = "./modules/s3-secure"
  bucket_name = "my-bucket"

  # The module always applies:
  # - AES-256 server-side encryption
  # - Access logging to a separate log bucket
  # - Versioning enabled
  # - Public access block on all four settings
  # Developers cannot opt out of these defaults
}
```

### Log Bucket Separation

```
App Bucket  →  stores data
Log Bucket  →  stores access logs (separate resource, separate permissions)
```

Separation ensures that even if the app bucket is compromised, log integrity is preserved.

### Network Isolation Rule

```
Public subnet   → load balancers only (internet-facing entry point)
Private subnet  → application servers, databases, internal services
```

Never put databases or internal services in a public subnet.

---

## Drift Detection

### What Drift Is

**Drift** = the difference between what your Terraform code describes and what actually exists in the cloud.

### Why It's a Security Risk

Drift can silently:
- Remove encryption from a bucket
- Re-open a security group that was locked down
- Weaken IAM policies
- Disable logging

None of this triggers an alert unless you're actively looking for it.

### How to Detect It

```bash
terraform plan
```

Compares desired state (your code) against actual state (AWS). Any difference is drift.

In production, this runs on a schedule in CI/CD — not just when someone remembers to check.

### Root Causes

| Cause | Example |
|---|---|
| Manual console changes | Developer "quickly" fixes something in the UI |
| Emergency fixes | Incident response bypasses the normal pipeline |
| External automation | A separate tool modifies the same resources |
| Lack of governance | No policy preventing direct console access |

### Prevention

- Enforce all changes through CI/CD — block console access to production where possible
- Run scheduled `terraform plan` jobs and alert on any diff
- Treat drift alerts the same as a security incident until proven otherwise

---

## Guardrails & Enforcement

### Three Layers

#### 1. Preventive (Strongest)

Stop bad infrastructure from being created at all.

| Tool | How It Works |
|---|---|
| Secure Terraform modules | Developers use pre-built modules with security baked in |
| Policy-as-code (OPA / Sentinel / Checkov) | CI/CD pipeline fails if code violates rules |
| AWS Service Control Policies (SCPs) | Hard account-level limits, even root can't bypass them |

Example SCP:
```json
{
  "Effect": "Deny",
  "Action": "s3:PutBucketPublicAccessBlock",
  "Resource": "*",
  "Condition": {
    "StringEquals": { "s3:PublicAccessBlockConfiguration/BlockPublicAcls": "false" }
  }
}
```

#### 2. Detective (Monitoring Layer)

Find issues that got through.

- **AWS Config** — continuously evaluates resources against compliance rules
- **CloudTrail** — logs every API call (who did what, when, from where)
- **SIEM** (Splunk, Datadog, Sentinel) — aggregates logs, triggers alerts

#### 3. Corrective (Auto-Remediation)

Automatically fix violations without human intervention.

```
AWS Config detects: S3 bucket is public
        ↓
Config rule triggers SSM Automation document
        ↓
SSM re-enables BlockPublicAccess
        ↓
Alert sent to security team for review
```

Or event-driven:

```
EventBridge: SecurityGroup rule changed to 0.0.0.0/0
        ↓
Lambda function triggered
        ↓
Lambda removes the offending rule
        ↓
Ticket created for post-incident review
```

### Full Pipeline View

```
Developer writes Terraform
         ↓
CI/CD: policy-as-code checks (Checkov / OPA / Sentinel)
         ↓
terraform plan reviewed and approved
         ↓
terraform apply → infrastructure deployed
         ↓
AWS Config: continuous compliance monitoring
         ↓
CloudTrail → SIEM: alerting on anomalies
         ↓
Auto-remediation: Lambda / SSM fixes violations
```

**Key principle:** *Insecure infrastructure should be impossible to deploy, not just detectable after the fact.*

---

## Terraform State Security

### Why State Is Sensitive

Terraform state files contain:
- Resource IDs and metadata
- Dependency graph of your infrastructure
- Potentially sensitive values (if not using secrets managers)

If an attacker gets your state file, they get a map of your entire infrastructure.

### Common Failures

| Failure | Impact |
|---|---|
| S3 state bucket not encrypted | State readable if bucket is accessed |
| State bucket publicly accessible | Full infrastructure map exposed |
| No DynamoDB locking | Concurrent applies cause state corruption |
| Broad IAM access to state bucket | Anyone with AWS access can read/modify state |

### Secure Backend Configuration

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-prod"
    key            = "infra/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true                        # AES-256 at rest
    dynamodb_table = "terraform-state-lock"      # Prevents concurrent applies
  }
}
```

State bucket IAM should follow least privilege — only the CI/CD service role should have write access.

---

## Common Attack Paths

Understanding how attackers think is as important as knowing defensive controls.

### Attack Chain: Over-Permissive IAM

```
1. Attacker finds role/user with iam:CreateUser + iam:AttachUserPolicy

2. Creates new IAM user: attacker-backdoor

3. Attaches AdministratorAccess policy

4. Full account takeover:
   - Delete CloudTrail logs (cover tracks)
   - Exfiltrate S3 data
   - Disable GuardDuty / Config
   - Create persistence mechanisms
```

### Attack Chain: Misconfigured Infrastructure

```
1. Attacker scans for public RDS instance (misconfigured subnet)

2. Extracts database contents

3. Finds AWS credentials in database (hardcoded by developer)

4. Uses credentials to assume IAM role with broader permissions

5. Moves laterally through account
```

### Attacker Preference

Attackers prefer misconfiguration over active exploitation. It's quieter, uses valid credentials, and often goes undetected for months. This is why prevention-first architecture matters.

---

## Interview Framework

### How to Answer Any Terraform Security Question

Use this structure:

1. **Identify the risk** — "What could go wrong here?"
2. **Describe the attack path** — "How would an attacker exploit it?"
3. **State the blast radius** — "What's the worst-case impact?"
4. **Layer the mitigations** — Prevent → Detect → Respond
5. **Acknowledge tradeoffs** — "This adds friction for developers, which is why we use X to reduce that"

### Example: "How would you secure Terraform in a large enterprise?"

Strong answer hits these points in order:

- Secure module library as the baseline (developers use pre-approved templates)
- IAM least privilege with no wildcard policies
- Policy-as-code gates in CI/CD (Checkov, OPA, or Sentinel)
- SCPs as hard account-level limits
- Encrypted, locked remote state with strict IAM
- Scheduled drift detection with alerting
- AWS Config + CloudTrail feeding into SIEM
- Auto-remediation for high-confidence violations
- Separation of duties between dev and security roles

### Signature Interview Line

> *"I approach Terraform security from a prevention-first perspective: secure defaults, least privilege IAM, and enforcement through guardrails rather than relying on developer discipline. Detection and remediation handle what prevention misses."*

---

## Quick Reference

### Terraform Commands

| Command | Purpose |
|---|---|
| `terraform init` | Initialize working directory |
| `terraform plan` | Preview changes (no modifications) |
| `terraform apply` | Apply changes to infrastructure |
| `terraform state list` | List resources in state |

### Tools by Layer

| Layer | Tools |
|---|---|
| Prevention | Terraform modules, OPA, Sentinel, Checkov, tfsec, SCPs |
| Detection | AWS Config, CloudTrail, GuardDuty, SIEM |
| Remediation | Lambda, SSM Automation, EventBridge, SOAR |
| State security | S3 + KMS + DynamoDB locking |

### Red Flags to Call Out Immediately

- `"Action": "*", "Resource": "*"` in any IAM policy
- S3 bucket without `block_public_access`
- Database resource in a public subnet
- Missing `encrypt = true` on S3/RDS/EBS
- No CloudTrail or logging configuration
- State backend without encryption or locking

---

*These notes reflect intermediate-level Terraform security concepts. Focus areas: IAM least privilege, secure defaults, drift detection, and layered enforcement.*

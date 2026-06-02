# Terraform Security Lab

![Terraform](https://img.shields.io/badge/Terraform-≥1.0-7B42BC?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-Policy_Scan-4CAF50?logo=checkmarx&logoColor=white)
![tfsec](https://img.shields.io/badge/tfsec-Security_Scan-blue)
![Gitleaks](https://img.shields.io/badge/Gitleaks-Secret_Scan-red)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Provider-FF9900?logo=amazon-aws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

A modular Terraform project demonstrating a production-style security engineering workflow — infrastructure as code with automated security scanning, secret detection, compliance policy enforcement, and custom policy tooling via GitHub Actions.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Modules](#modules)
- [CI/CD Security Pipeline](#cicd-security-pipeline)
- [Custom Security Scanner](#custom-security-scanner)
- [Bad PR Simulation](#bad-pr-simulation)
- [Security Model](#security-model)
- [Technologies](#technologies)
- [Getting Started](#getting-started)

---

## Overview

This lab simulates a real-world security engineering pipeline. Every pull request is automatically scanned for infrastructure misconfigurations, compliance violations, committed secrets, and organization-specific policy violations before it can be merged.

**Core objectives:**

| Objective | Implementation |
|---|---|
| Modular infrastructure design | Reusable Terraform modules per service domain |
| Automated security scanning | tfsec + Checkov as blocking pipeline stages |
| Secret detection | Gitleaks scanning full git history on every PR |
| Organization-specific policy enforcement | Custom Python scanner with 5 internal rules |
| Compliance documentation | SECURITY.md documenting all findings and accepted risks |
| Adversarial testing | Bad PR simulation proving pipeline catches real attacks |

---

## Project Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform.yml       # 5-job security pipeline
├── modules/
│   ├── vpc/                    # Network topology and subnets
│   ├── ec2/                    # Compute instance configuration
│   ├── iam/                    # Roles, policies, and permissions
│   ├── s3/                     # S3 bucket with encryption and versioning
│   └── logging/                # CloudTrail and centralized logging
├── scanner/
│   └── scanner.py              # Custom Python security scanner
├── tests/
│   └── bad-infra/
│       └── main.tf             # Intentionally insecure Terraform (pipeline test)
├── main.tf
├── variables.tf
├── outputs.tf
├── provider.tf
└── SECURITY.md                 # Security controls and remediation documentation
```

---

## Modules

Each module encapsulates a single infrastructure concern with secure defaults enforced.

| Module | Responsibility | Security Controls |
|---|---|---|
| `vpc` | VPC, subnets, default SG lockdown | Public IP disabled, default SG denies all traffic |
| `ec2` | Compute instance | IMDSv2 enforced, EBS encrypted, detailed monitoring |
| `iam` | Roles and instance profiles | Least-privilege, no wildcard actions |
| `s3` | Log storage bucket | Encryption, versioning, public access blocked |
| `logging` | CloudTrail configuration | Log file validation, lifecycle policy |

---

## CI/CD Security Pipeline

Defined in `.github/workflows/terraform.yml` and triggered on every push and pull request. Each job runs in isolation — a failure in one job does not suppress results from others.

```
Pull Request opened
        │
        ▼
┌─────────────────────────┐
│  Job 1: terraform-checks │  fmt -check + validate (foundation gate)
└────────────┬────────────┘
             │ needs: terraform-checks
    ┌────────┴──────────────────────────┐
    ▼          ▼            ▼           ▼
┌────────┐ ┌────────┐ ┌─────────┐ ┌──────────────┐
│ tfsec  │ │Checkov │ │Gitleaks │ │Custom Scanner│
│        │ │        │ │         │ │              │
│IaC     │ │Policy  │ │Secret   │ │Org-specific  │
│security│ │CIS/SOC2│ │scanning │ │policies      │
└────────┘ └────────┘ └─────────┘ └──────────────┘
    │          │            │           │
    └──────────┴────────────┴───────────┘
                     │
              All must pass
                     │
              PR can merge
```

| Job | Tool | Blocks merge? | What it catches |
|---|---|---|---|
| Terraform Format & Validate | terraform fmt / validate | Yes | Syntax errors, formatting drift |
| tfsec Security Scan | tfsec | Yes | IaC misconfigurations |
| Checkov Policy Scan | Checkov | Soft fail (documented exceptions) | CIS, SOC2, PCI-DSS violations |
| Secret Scan | Gitleaks | Yes | Credentials in git history |
| Custom Security Scanner | scanner.py | Yes (CRITICAL/HIGH) | Org-specific policy violations |

---

## Custom Security Scanner

`scanner/scanner.py` is a Python tool written from scratch that enforces organization-specific policies that generic tools cannot know about. It runs as a standalone CLI tool in the pipeline and exits with code 1 on CRITICAL or HIGH findings, blocking the PR automatically.

### Rules enforced

| Rule | Severity | Policy |
|---|---|---|
| TAG-001 | HIGH | All AWS resources must have: Environment, Owner, Project, DataClassification |
| NAME-001 | MEDIUM | Resources must follow naming convention: {project}-{env}-{purpose} |
| RGN-001 | HIGH | Deployments only permitted in us-east-1 and us-west-2 |
| ACCT-001 | CRITICAL | No hardcoded AWS account IDs — use var.aws_account_id |
| S3-001 | MEDIUM | All S3 buckets must have aws_s3_bucket_logging configured |

### Run locally

```bash
python scanner/scanner.py --path .
python scanner/scanner.py --path . --fail-on-findings
```

### Why these rules exist

**Tagging** — enables cost attribution by business unit, identifies resource ownership during incident response, and supports data classification for compliance reporting.

**Naming conventions** — enforces operational consistency and enables scripted automation against predictable resource names.

**Region restrictions** — enforces compliance boundary control. Resources outside approved regions fall outside monitored security controls and may violate data residency requirements.

**No hardcoded account IDs** — reduces attack surface by keeping account identifiers out of source code. Enables account portability for disaster recovery.

**S3 logging** — ensures audit trail exists for all bucket access. Without access logs, answering "who accessed this data?" during an incident is impossible.

---

## Bad PR Simulation

To validate that the pipeline catches real security misconfigurations, a deliberately insecure Terraform file was introduced as a pull request in the `bad-infra/simulate-insecure-pr` branch. Three vulnerabilities were simulated.

First, an S3 bucket was configured with all public access controls disabled — `block_public_acls`, `block_public_policy`, `ignore_public_acls`, and `restrict_public_buckets` all set to false, exposing any stored data to the internet. Second, a security group was configured to allow inbound SSH from `0.0.0.0/0`, opening port 22 to every IP address on the internet and enabling brute-force attacks from any source. Third, a wildcard IAM policy was created granting `Action: ["*"]` on `Resource: "*"` — effectively root-level access to the entire AWS account, which a compromised identity could use to exfiltrate data, spin up resources, or create backdoor accounts.

The Checkov scan detected all three vulnerabilities and failed the pipeline, blocking the PR from merging into main. The bad PR remains open on the repository as permanent evidence of the pipeline working as intended.

This simulation exists to prove that the security pipeline is not theoretical — it catches real attack patterns before they reach production infrastructure.

**Findings detected:**

| Finding | Rule | Vulnerability |
|---|---|---|
| CKV_AWS_53/54/55/56 | S3 public access | Public S3 bucket |
| CKV_AWS_24 | Unrestricted SSH | Open port 22 to 0.0.0.0/0 |
| CKV_AWS_62 | Wildcard IAM | Full account permissions |

---

## Security Model

All security findings are documented in [SECURITY.md](SECURITY.md) with remediation details or accepted risk justification.

### Controls implemented

| Control | Resource | Implementation |
|---|---|---|
| IMDSv2 enforced | EC2 | http_tokens = required |
| EBS encryption | EC2 | root_block_device encrypted = true |
| Detailed monitoring | EC2 | monitoring = true |
| Public access blocked | S3 | block_public_* = true |
| Log file validation | CloudTrail | enable_log_file_validation = true |
| Log retention policy | S3/CloudTrail | Lifecycle: 90d → STANDARD_IA, 365d → expire |
| Default SG lockdown | VPC | aws_default_security_group, no rules |
| Public IP disabled | VPC subnet | map_public_ip_on_launch = false |

### Accepted risks

Two findings are accepted as risk for this non-production lab environment and documented in SECURITY.md:

- **CKV_AWS_35** — CloudTrail KMS encryption (cost: $1/month per key, lab environment)
- **CKV_AWS_252** — CloudTrail SNS notification (requires additional infrastructure, out of scope)

---

## Technologies

| Tool | Purpose |
|---|---|
| [Terraform](https://www.terraform.io/) ≥ 1.0 | Infrastructure as Code |
| [GitHub Actions](https://github.com/features/actions) | CI/CD orchestration |
| [tfsec](https://aquasecurity.github.io/tfsec/) | Terraform security scanning |
| [Checkov](https://www.checkov.io/) | IaC compliance policy scanning |
| [Gitleaks](https://github.com/gitleaks/gitleaks) | Secret detection in git history |
| [Python 3.12](https://www.python.org/) | Custom security scanner |
| [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) | AWS resource definitions |

---

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- Python 3.12
- [Checkov](https://www.checkov.io/2.Basics/Installing%20Checkov.html) *(optional — for local scans)*

### Run security checks locally

```bash
# Terraform checks
terraform init -backend=false
terraform fmt -check -recursive
terraform validate

# Custom scanner
python scanner/scanner.py --path .
python scanner/scanner.py --path . --fail-on-findings

# Checkov
checkov -d . --framework terraform
```

---

## License

This project is open source and available under the [MIT License](LICENSE).
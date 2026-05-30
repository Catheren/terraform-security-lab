# Terraform Infrastructure CI Lab

![Terraform](https://img.shields.io/badge/Terraform-≥1.0-7B42BC?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-Security_Scan-4CAF50?logo=checkmarx&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Provider-FF9900?logo=amazon-aws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

A modular Terraform project demonstrating a production-style IaC workflow with automated validation, static security analysis, and change previewing via GitHub Actions — **no live cloud deployment**.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Modules](#modules)
- [CI/CD Pipeline](#cicd-pipeline)
- [Security Model](#security-model)
- [Artifacts](#artifacts)
- [Design Decisions](#design-decisions)
- [Technologies](#technologies)
- [Getting Started](#getting-started)

---

## Overview

This lab simulates a real-world infrastructure engineering pipeline focused on correctness, security posture, and change visibility — without provisioning any cloud resources.

**Core objectives:**

| Objective | Implementation |
|---|---|
| Modular infrastructure design | Reusable Terraform modules per service domain |
| Automated validation | `terraform fmt`, `validate`, and `plan` in CI |
| Shift-left security | Checkov static analysis as a blocking pipeline stage |
| Safe change previewing | Terraform plan with no apply step |

---

## Project Structure

```
.
├── modules/
│   ├── vpc/                  # Network topology and subnets
│   ├── ec2/                  # Compute instance configuration
│   ├── iam/                  # Roles, policies, and permissions
│   ├── s3_logs/              # S3 bucket for log storage
│   └── logging/              # Centralized logging infrastructure
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
└── .github/
    └── workflows/
        └── terraform-ci.yml
```

---

## Modules

Each module encapsulates a single infrastructure concern, promoting separation of responsibility and independent testability.

| Module | Responsibility |
|---|---|
| `vpc` | VPC, subnets, route tables, internet gateway |
| `ec2` | Instance type, AMI, security groups, key pairs |
| `iam` | Least-privilege roles, instance profiles, policy attachments |
| `s3_logs` | Log bucket with access controls and lifecycle rules |
| `logging` | Centralized log aggregation and retention configuration |

---

## CI/CD Pipeline

Defined in `.github/workflows/terraform-ci.yml` and triggered on every `push` and `pull_request`.

```
┌─────────────────────┐
│   Terraform Init    │  Initialises providers and modules
└────────┬────────────┘
         ↓
┌─────────────────────┐
│   Format Check      │  terraform fmt -check (fails on drift)
└────────┬────────────┘
         ↓
┌─────────────────────┐
│   Validate          │  Syntax and internal consistency check
└────────┬────────────┘
         ↓
┌─────────────────────┐
│   Checkov Scan      │  Static IaC security analysis (blocking)
└────────┬────────────┘
         ↓
┌─────────────────────┐
│   Terraform Plan    │  Dry-run — no resources are created
└─────────────────────┘
```

> Each stage is a hard gate. A failure at any step blocks the subsequent stages and prevents merge.

---

## Security Model

### Threat Model Scope

This project addresses **IaC misconfiguration risk** — the leading cause of cloud security incidents. The attack surface is limited to Terraform configuration changes; runtime threats are out of scope as no environment is deployed.

### Risk Areas and Controls

| Risk | Threat | Control |
|---|---|---|
| Over-permissive IAM | Privilege escalation, lateral movement | Checkov policy rules + least-privilege module design |
| Public resource exposure | Unintended data exposure | Checkov public access checks |
| Missing encryption | Data at rest/in transit unprotected | Checkov encryption rules |
| Permissive security groups | Unrestricted inbound/outbound traffic | Checkov network rules |
| Configuration drift | Inconsistent or broken state | `terraform fmt` + `terraform validate` |
| Unapproved changes | Infrastructure changes without review | Terraform plan surfaced as a PR artifact |

### Shift-Left Enforcement

Security scanning runs **before** the plan stage, ensuring misconfigured code never produces an actionable execution plan:

```
Validate → [Checkov PASS] → Plan    ✅
Validate → [Checkov FAIL] → ✗ Blocked, pipeline fails
```

When Checkov detects a violation, the GitHub Actions workflow fails immediately, the finding is logged in the job output, and the PR cannot be merged until resolved.

---

## Artifacts

The pipeline saves the following downloadable artifacts on each run:

| Artifact | Contents | Purpose |
|---|---|---|
| `plan.txt` | Full Terraform plan output | Review proposed infrastructure changes |
| Checkov report | Static analysis findings | Audit trail of security scan results |

Artifacts persist after CI execution, enabling asynchronous review and compliance record-keeping.

---

## Design Decisions

**No `terraform apply`**
This is an intentional constraint. The project validates infrastructure design and security posture at the code level. Deployment is outside the scope of this lab.

**No remote state (S3 backend)**
Local state keeps the project self-contained with no external dependencies, allowing it to be cloned and run in isolation without AWS credentials or pre-existing infrastructure.

**Checkov as a blocking stage**
Security scanning is positioned before `terraform plan` to ensure no execution plan is generated from insecure configurations. This reflects a security-first pipeline philosophy.

---

## Technologies

| Tool | Version | Purpose |
|---|---|---|
| [Terraform](https://www.terraform.io/) | ≥ 1.0 | Infrastructure as Code |
| [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) | Latest | AWS resource definitions |
| [GitHub Actions](https://github.com/features/actions) | — | CI/CD orchestration |
| [Checkov](https://www.checkov.io/) | Latest | Static IaC security analysis |

---

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Checkov](https://www.checkov.io/2.Basics/Installing%20Checkov.html) *(optional — for local security scans)*

### Run the Pipeline Locally

```bash
# Initialise providers and modules
terraform init

# Verify formatting
terraform fmt -check

# Validate configuration
terraform validate

# Preview infrastructure changes
terraform plan
```

### Run Security Scan Locally

```bash
# Scan all Terraform files in the current directory
checkov -d .

# Output results in JUnit format (for CI integration)
checkov -d . -o junitxml > checkov-report.xml
```

---

## License

This project is open source and available under the [MIT License](LICENSE).

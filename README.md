# Terraform Infrastructure CI Lab

![Terraform](https://img.shields.io/badge/Terraform-IaC-7B42BC?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?logo=github-actions&logoColor=white)
![Checkov](https://img.shields.io/badge/Checkov-Security_Scan-4CAF50?logo=checkmarx&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Provider-FF9900?logo=amazon-aws&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-blue)

A modular Terraform project with a fully automated CI/CD validation pipeline using GitHub Actions and Checkov security scanning — **no live cloud deployment required**.

---

## Table of Contents

- [Overview](#-overview)
- [Project Structure](#-project-structure)
- [Key Features](#-key-features)
- [CI/CD Pipeline](#-cicd-pipeline)
- [Security Scanning](#-security-scanning)
- [Design Decisions](#-design-decisions)
- [Technologies Used](#-technologies-used)
- [Getting Started](#-getting-started)

---

## Overview

This project demonstrates a production-style Infrastructure as Code (IaC) workflow, simulating a real-world infrastructure engineering pipeline without deploying to a live cloud environment.

The focus is on:

- **Terraform modular design** — reusable, maintainable infrastructure components
- **CI/CD validation** — automated checks on every push and pull request
- **Security scanning** — static analysis with Checkov to catch misconfigurations early
- **Change previewing** — safe Terraform plan output with no apply step

---

##  Project Structure

```
.
├── modules/
│   ├── vpc/           # VPC networking
│   ├── ec2/           # Compute resources
│   ├── iam/           # Roles and policies
│   ├── s3_logs/       # S3 logging configuration
│   └── logging/       # Logging infrastructure
├── main.tf
├── variables.tf
├── outputs.tf
├── providers.tf
└── .github/
    └── workflows/
        └── terraform-ci.yml
```

---

##  Key Features

###  Modular Terraform Architecture

Infrastructure is split into focused, reusable modules:

| Module | Purpose |
|---|---|
| `vpc` | Network topology and subnets |
| `ec2` | Compute instance configuration |
| `iam` | Roles, policies, and permissions |
| `s3_logs` | S3 bucket for log storage |
| `logging` | Centralized logging infrastructure |

This separation improves **maintainability**, **testability**, and **scalability**.

---

###  CI/CD Pipeline (GitHub Actions)

Every `push` and `pull_request` triggers an automated pipeline with the following stages:

```
Terraform Init
      ↓
Format Check (terraform fmt)
      ↓
Validate (terraform validate)
      ↓
Checkov Security Scan
      ↓
Terraform Plan (dry-run)
```

---

###  Security Scanning (Checkov)

Static infrastructure analysis is performed by [Checkov](https://www.checkov.io/) to detect common misconfigurations before they reach production:

- Misconfigured IAM policies
- Public access risks on S3 or EC2
- Missing encryption at rest or in transit
- Overly permissive security group rules

---

### Terraform Plan (No Deployment)

The pipeline generates a full execution plan showing:

- Resources to be **created**
- Resources to be **modified**
- Resources to be **destroyed**

>  **No infrastructure is deployed.** This project is intentionally designed as a safe validation lab.

---

## CI/CD Pipeline

Defined in `.github/workflows/terraform-ci.yml`:

```yaml
on:
  push:
  pull_request:

jobs:
  terraform:
    steps:
      - Checkout repository
      - Terraform Init
      - Terraform Format Check
      - Terraform Validate
      - Checkov Security Scan
      - Terraform Plan
```

---

## Security Scanning

Checkov is configured to scan all Terraform files and flag issues across common AWS services. Results are surfaced directly in the GitHub Actions workflow logs and can be integrated with PR checks to block merges on critical findings.

---

## Design Decisions

**Why no `terraform apply`?**
This project is a **CI demonstration lab** — the goal is to validate infrastructure correctness and security posture, not to provision real resources.

**Why no remote state (S3 backend)?**
Local state keeps the project self-contained with zero external dependencies, making it easy to clone and run immediately.


## Security Model (Threat Analysis)

This project focuses on infrastructure security at the code level (IaC), without deploying to a live cloud environment.

### Threat Model Assumptions
- Misconfigurations in infrastructure code are the primary risk
- No runtime environment is deployed, so runtime attacks are out of scope
- The main attack surface is Terraform configuration changes

### Security Risks Considered
- Insecure IAM policies (over-permissive access)
- Public exposure of infrastructure resources
- Missing encryption or data protection controls
- Misconfigured networking rules

### Security Controls Implemented

| Risk Area              | Control Used        | Purpose |
|----------------------|---------------------|----------|
| Infrastructure flaws | Terraform Validate  | Ensures configuration correctness |
| Code formatting drift | Terraform fmt check | Prevents inconsistent code states |
| Security misconfigurations | Checkov | Static IaC security analysis |
| Infrastructure changes | Terraform Plan | Previews all changes before execution |

### Security Approach
This project follows a "shift-left security" approach where security checks are executed early in the CI pipeline before any potential deployment stage.
---

## Technologies Used

| Tool | Purpose |
|---|---|
| [Terraform](https://www.terraform.io/) | Infrastructure as Code |
| [AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest) | Cloud resource definitions |
| [GitHub Actions](https://github.com/features/actions) | CI/CD automation |
| [Checkov](https://www.checkov.io/) | Static security analysis |

---

## Getting Started

### Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.0
- [Checkov](https://www.checkov.io/2.Basics/Installing%20Checkov.html) (optional, for local scans)

### Run Locally

```bash
# Initialize working directory
terraform init

# Check formatting
terraform fmt -check

# Validate configuration
terraform validate

# Preview infrastructure changes
terraform plan
```

### Run Security Scan Locally

```bash
checkov -d .
```
---------------------------------
## CI Pipeline Outputs

This project generates the following outputs in GitHub Actions:

### 1. Terraform Validation
Ensures Terraform configuration is syntactically correct and internally consistent.

### 2. Security Scan (Checkov)
Performs static analysis of infrastructure code to detect security misconfigurations.

### 3. Terraform Plan (Dry Run)
Generates a preview of infrastructure changes without applying them.

Plan output is saved as an artifact in GitHub Actions for review.
----------------------------------
## CI Artifacts

The pipeline generates downloadable artifacts:

- Terraform plan output (`plan.txt`)
- Security scan logs (Checkov output)

These artifacts allow infrastructure changes to be reviewed even after CI execution.

---------------------------------------
## What This Project Demonstrates

- Infrastructure as Code (Terraform)
- Modular infrastructure design
- CI/CD pipeline design using GitHub Actions
- Static security analysis (Checkov)
- Infrastructure change previewing without deployment
---

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

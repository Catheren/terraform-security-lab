#!/usr/bin/env python3
"""
Detects if the terraform script fails to follow 
any custom requirements of the org.

Enforces organization-specific policies that generic tools
(tfsec, Checkov) cannot know about. Designed to run as a
GitHub Actions job and block PRs that violate internal standards.
   
Rules Enforced: 
TAG-001 — Required tags on every resource
         (Environment, Owner, Project, DataClassification)

NAME-001 — Naming convention enforcement
         (all resources must follow: lab-{env}-{purpose})

RGN-001 — Approved regions only
         (only us-east-1 and us-west-2 allowed — no accidental
          deployments to regions outside your compliance boundary)

ACCT-001 — No hardcoded account IDs
         (should use variables, not literal AWS account numbers)

S3-001 — Every S3 bucket must have a logging target defined
         (tfsec checks encryption — you check logging destination)
"""
import argparse
import re
import sys
from pathlib import Path

REQUIRED_TAGS = {"Environment", "Owner", "Project", "DataClassification"}
APPROVED_REGIONS = {"us-east-1", "us-west-2"}
NAMING_PATTERN = r'^([a-zA-Z0-9]+)-([a-zA-Z0-9]+)-([a-zA-Z0-9]+)$'
ACCOUNT_ID_PATTERN = r'"\d{12}"'

def find_tf_files(path):
    return list(Path(path).rglob("*.tf"))



def make_finding(severity, rule_id, title, file, line, remediation):
    return {
        "severity": severity,
        "rule_id": rule_id,
        "title": title,
        "file": file,
        "line": line,
        "remediation": remediation
    }


def check_required_tags(content, filepath):
    findings = []

    # skip files with no AWS resources
    if not re.search(r'resource\s+"aws_', content):
        return findings

    # find the tags block inside the file
    tag_block = re.search(r'tags\s*=\s*\{([^}]+)\}', content)

    # if no tags block exists at all
    if not tag_block:
        findings.append(make_finding(
            severity="HIGH",
            rule_id="TAG-001",
            title="Missing tags block",
            file=filepath,
            line=1,
            remediation="Add a tags block with: Environment, Owner, Project, DataClassification"
        ))
        return findings

    # extract which tags are present
    tags_found = set(re.findall(r'(\w+)\s*=', tag_block.group(1)))

    # check each required tag individually
    for tag in REQUIRED_TAGS:
        if tag not in tags_found:
            findings.append(make_finding(
                severity="HIGH",
                rule_id="TAG-001",
                title=f"Missing required tag: {tag}",
                file=filepath,
                line=1,
                remediation=f"Add '{tag}' to the tags block"
            ))

    return findings

def check_naming_convention(content, filepath):
    findings = []

    # extract all resource names from the file
    # terraform resource syntax: resource "type" "name"
    resources = re.findall(r'resource\s+"[\w]+"\s+"([\w-]+)"', content)

    for name in resources:
        if not re.match(NAMING_PATTERN, name):
            findings.append(make_finding(
                severity="MEDIUM",
                rule_id="NAME-001",
                title=f"Resource name does not follow convention: {name}",
                file=filepath,
                line=1,
                remediation="Rename to follow pattern: {project}-{env}-{purpose}"
            ))

    return findings


def check_approved_regions(content, filepath):
    findings = []

    # find any hardcoded region strings in the file
    regions_found = re.findall(r'"([a-z]+-[a-z]+-[0-9])"', content)

    for region in regions_found:
        if region not in APPROVED_REGIONS:
            findings.append(make_finding(
                severity="HIGH",
                rule_id="RGN-001",
                title=f"Unapproved region detected: {region}",
                file=filepath,
                line=1,
                remediation=f"Only use approved regions: {APPROVED_REGIONS}"
            ))

    return findings



def check_hardcoded_account_ids(content, filepath):
    findings = []

    matches = re.finditer(ACCOUNT_ID_PATTERN, content)

    for match in matches:
        line = content[:match.start()].count("\n") + 1
        findings.append(make_finding(
            severity="CRITICAL",
            rule_id="ACCT-001",
            title="Hardcoded AWS account ID detected",
            file=filepath,
            line=line,
            remediation="Replace with var.aws_account_id"
        ))

    return findings

def check_s3_logging(content, filepath):
    findings = []

    # only check files that define S3 buckets
    if not re.search(r'resource\s+"aws_s3_bucket"', content):
        return findings

    # check if logging configuration exists
    if not re.search(r'aws_s3_bucket_logging', content):
        findings.append(make_finding(
            severity="MEDIUM",
            rule_id="S3-001",
            title="S3 bucket missing access logging configuration",
            file=filepath,
            line=1,
            remediation="Add an aws_s3_bucket_logging resource pointing to a log bucket"
        ))

    return findings


# all rule functions in one list
# to add a new rule later, just append it here
RULES = [
    check_required_tags,
    check_naming_convention,
    check_approved_regions,
    check_hardcoded_account_ids,
    check_s3_logging,
]


def scan(path):
    findings = []
    tf_files = find_tf_files(path)

    if not tf_files:
        print(f"No .tf files found in {path}")
        return findings

    # run every rule against every file
    for tf_file in tf_files:
        content = tf_file.read_text(encoding="utf-8", errors="ignore")
        for rule in RULES:
            findings.extend(rule(content, str(tf_file)))

    return findings



def print_report(findings):
    if not findings:
        print("✅ No findings. All checks passed.")
        return

    # sort by severity — CRITICAL first, then HIGH, then MEDIUM
    order = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2}
    findings.sort(key=lambda f: order[f["severity"]])

    print(f"\n{'─' * 60}")
    print(f"  Custom Scanner — {len(findings)} finding(s)")
    print(f"{'─' * 60}\n")

    for f in findings:
        icon = {"CRITICAL": "🔴", "HIGH": "🟠", "MEDIUM": "🟡"}[f["severity"]]
        print(f"{icon} [{f['severity']}] {f['rule_id']}: {f['title']}")
        print(f"   File:        {f['file']}:{f['line']}")
        print(f"   Remediation: {f['remediation']}")
        print()


def main():
    # define command line arguments
    parser = argparse.ArgumentParser(description="Custom Terraform Security Scanner")
    parser.add_argument("--path", default=".", help="Path to scan")
    parser.add_argument("--fail-on-findings", action="store_true",
                        help="Exit 1 if CRITICAL or HIGH findings exist")
    args = parser.parse_args()

    # run the scan
    findings = scan(args.path)

    # print the report
    print_report(findings)

    # fail the pipeline if critical or high findings exist
    if args.fail_on_findings:
        for f in findings:
            if f["severity"] in ("CRITICAL", "HIGH"):
                sys.exit(1)


# entry point — only runs when script is executed directly
# not when imported as a module
if __name__ == "__main__":
    main()
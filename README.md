# AWS DevSecOps CI/CD Pipeline

<p align="center">
  <strong>A Security-Focused CI/CD Pipeline on AWS</strong>
  <br/>
  Automating application security, container scanning, infrastructure security, and cloud deployment.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/AWS-Cloud-orange?logo=amazonaws" alt="AWS"/>
  <img src="https://img.shields.io/badge/Docker-Containerization-blue?logo=docker" alt="Docker"/>
  <img src="https://img.shields.io/badge/Terraform-Infrastructure%20as%20Code-7B42BC?logo=terraform" alt="Terraform"/>
  <img src="https://img.shields.io/badge/GitHub%20Actions-CI%2FCD-2088FF?logo=githubactions" alt="GitHub Actions"/>
  <img src="https://img.shields.io/badge/Trivy-Security%20Scanning-1904DA" alt="Trivy"/>
  <img src="https://img.shields.io/badge/Checkov-IaC%20Security-5C4EE5" alt="Checkov"/>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Project%20Status-Completed-success" alt="Project completed"/>
  <img src="https://img.shields.io/badge/Version-1.0-blue" alt="Version 1.0"/>
  <img src="https://img.shields.io/badge/AWS%20Region-ap--southeast--1-orange" alt="AWS Singapore"/>
</p>

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Technology Stack](#3-technology-stack)
4. [Repository Structure](#4-repository-structure)
5. [Application](#5-application)
6. [Docker Container Security](#6-docker-container-security)
7. [CI/CD Pipeline](#7-cicd-pipeline)
8. [Security Results](#8-security-results)
9. [GitHub-to-AWS Authentication](#9-github-to-aws-authentication)
10. [AWS Deployment](#10-aws-deployment)
11. [Terraform Infrastructure](#11-terraform-infrastructure)
12. [Reproduction Guide](#12-reproduction-guide)
13. [Cost Management](#13-cost-management)
14. [Limitations and Future Improvements](#14-limitations-and-future-improvements)
15. [Project Completion](#15-project-completion)

---

## 1. Project Overview

### Objective

Design and implement a security-focused CI/CD pipeline that automates application security scanning, Docker image building, infrastructure security assessment, and container image publishing to AWS.

The project demonstrates how security practices can be integrated throughout the application delivery process using DevSecOps principles.

### Key Objectives

- Integrate automated security checks into CI/CD.
- Detect exposed secrets before application delivery.
- Scan application dependencies, filesystems, and Docker images.
- Identify infrastructure misconfigurations using Checkov.
- Implement secure GitHub-to-AWS authentication using OIDC.
- Publish immutable Docker images to Amazon ECR.
- Deploy a hardened containerized application using Amazon ECS Fargate.
- Manage selected AWS infrastructure using Terraform.
- Centralize application logs using Amazon CloudWatch.

### Project Repository

**GitHub:** [AWS-DevSecOps-Pipeline](https://github.com/bryanwork6099/AWS-DevSecOps-Pipeline)

**Project status:** Completed — Version 1.0

---

## 2. Architecture

### High-Level Architecture

```text
                  DEVELOPER
                      |
                      v
              GITHUB REPOSITORY
                      |
                      v
               GITHUB ACTIONS
                      |
          +-----------+-----------+
          |           |           |
          v           v           v
       Checkov     Gitleaks     Trivy
       Terraform    Secrets    Filesystem
          |           |           |
          +-----------+-----------+
                      |
                      v
                 DOCKER BUILD
                      |
                      v
                TRIVY IMAGE SCAN
                      |
                      v
              GITHUB OIDC FEDERATION
                      |
                      v
                  AWS IAM ROLE
                      |
                      v
                 AMAZON ECR
                Image Registry
                      |
                      v
              AMAZON ECS FARGATE
                      |
                      v
              AMAZON CLOUDWATCH
                 Container Logs
```

### Deployment Workflow

The GitHub Actions pipeline automatically:

1. Checks out the repository.
2. Scans Terraform configuration using Checkov.
3. Detects exposed secrets using Gitleaks.
4. Scans the filesystem using Trivy.
5. Builds the Docker image.
6. Scans the Docker image using Trivy.
7. Authenticates to AWS using GitHub OIDC.
8. Logs in to Amazon ECR.
9. Publishes the Docker image to ECR.

**Deployment note:** ECS Fargate was provisioned and verified separately using Terraform and AWS console/CLI operations. The current GitHub Actions workflow publishes images to ECR but does not automatically update the ECS service after each image push.

---

## 3. Technology Stack

| Category | Technology | Purpose |
|---|---|---|
| Application | Python, Flask | Web application |
| Containerization | Docker | Application containerization |
| CI/CD | GitHub Actions | Pipeline automation |
| Secret Detection | Gitleaks | Detect exposed credentials |
| Vulnerability Scanning | Trivy | Filesystem and image scanning |
| IaC Security | Checkov | Terraform security scanning |
| Infrastructure as Code | Terraform | AWS infrastructure management |
| Container Registry | Amazon ECR | Docker image storage |
| Container Deployment | Amazon ECS Fargate | Container execution |
| Identity and Access | AWS IAM, OIDC | Secure federated authentication |
| Monitoring | Amazon CloudWatch | Container logs |

---

## 4. Repository Structure

```text
AWS-DevSecOps-Pipeline/
│
├── app/
│   ├── __init__.py
│   └── main.py
│
├── tests/
│   └── test_main.py
│
├── terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tf
│   └── variables.tf
│
├── .github/
│   └── workflows/
│       └── security.yml
│
├── .gitleaks.toml
├── .dockerignore
├── .gitignore
├── Dockerfile
├── README.md
└── requirements.txt
```

> **Note:** Terraform's local `.terraform/` directory and state files are excluded from Git to avoid committing provider binaries and potentially sensitive infrastructure state.

---

## 5. Application

The project uses a Python Flask application with two HTTP endpoints.

| Endpoint | Description | Expected Result |
|---|---|---|
| `/` | Application information | HTTP 200 |
| `/health` | Application health check | HTTP 200 |

### Run Locally

Install dependencies:

```powershell
python -m pip install -r requirements.txt
```

Start the application:

```powershell
python app/main.py
```

Test the endpoints:

```powershell
Invoke-RestMethod http://localhost:5000/
Invoke-RestMethod http://localhost:5000/health
```

---

## 6. Docker Container Security

The application is containerized using `python:3.13-slim`.

### Implemented Security Controls

| Security Control | Implementation |
|---|---|
| Minimal base image | Python slim image |
| Non-root execution | Dedicated `appuser` |
| Read-only filesystem | ECS `readonlyRootFilesystem` |
| Health monitoring | Docker HEALTHCHECK |
| Production server | Gunicorn |
| Runtime hardening | pip removed after dependency installation |
| Writable temporary storage | Gunicorn worker directory configured to `/dev/shm` |

### Build and Run Docker Image

```powershell
docker build -t devsecops-app:local .
```

```powershell
docker run --rm -p 5000:5000 devsecops-app:local
```

Verify the application:

```powershell
Invoke-RestMethod http://localhost:5000/
Invoke-RestMethod http://localhost:5000/health
```

**Security consideration:** The Trivy pipeline fails on applicable HIGH and CRITICAL findings while using `ignore-unfixed: true`. Unfixed vulnerabilities are excluded from the failure condition, not proven absent. Scan results should still be reviewed.

---

## 7. CI/CD Pipeline

**Workflow:** `.github/workflows/security.yml`

The pipeline is triggered by:

- Pushes to `main`.
- Pull requests targeting `main`.

### Pipeline Stages

| Stage | Tool | Function |
|---|---|---|
| 1 | GitHub Checkout | Retrieve source code |
| 2 | Checkov | Scan Terraform configuration |
| 3 | Gitleaks | Detect exposed secrets |
| 4 | Trivy | Scan filesystem |
| 5 | Docker | Build application image |
| 6 | Trivy | Scan Docker image |
| 7 | AWS OIDC | Authenticate to AWS |
| 8 | Amazon ECR Login | Authenticate Docker to ECR |
| 9 | Amazon ECR Push | Publish container image |

### Pipeline Execution Conditions

| Workflow Event | Security Scanning | Docker Build | ECR Publishing |
|---|---|---|---|
| Push to `main` | Yes | Yes | Yes |
| Pull request to `main` | Yes | Yes | No |

AWS authentication and ECR publishing are restricted to pushes to `main`.

### Trivy Configuration

Both Trivy scans use:

```yaml
severity: HIGH,CRITICAL
ignore-unfixed: true
exit-code: '1'
```

This causes the pipeline to fail when the configured scan identifies applicable HIGH or CRITICAL findings.

---

## 8. Security Results

### Checkov — Terraform Security Scan

<details>
<summary><strong>View Checkov results</strong></summary>

| Result | Count |
|---|---:|
| Passed | 10 |
| Failed | 0 |
| Skipped | 4 |

**Documented exceptions:**

| Check ID | Reason |
|---|---|
| CKV_AWS_136 | AWS-managed AES-256 ECR encryption is used instead of a customer-managed KMS key to avoid additional key costs. |
| CKV_AWS_224 | ECS Exec is intentionally disabled. Application logs are sent to CloudWatch. |
| CKV_AWS_65 | Container Insights is disabled to limit monitoring costs. |
| CKV_AWS_333 | Public IP assignment is retained for this low-cost portfolio deployment. Inbound TCP 5000 is restricted to the administrator's public IP. |

These are documented exceptions, not passed security checks. Reassess them before production use.

</details>

### Security Controls Summary

| Security Area | Implementation |
|---|---|
| Secret Detection | Gitleaks |
| Vulnerability Assessment | Trivy |
| Infrastructure Security | Checkov |
| AWS Authentication | GitHub OIDC |
| IAM Permissions | Restricted ECR publishing permissions |
| Image Integrity | Immutable ECR tags |
| Container Privileges | Non-root execution |
| Filesystem Protection | Read-only root filesystem |
| Health Monitoring | Docker health check |
| Network Security | Restricted inbound access |

---

## 9. GitHub-to-AWS Authentication

GitHub Actions authenticates to AWS through GitHub's OIDC identity provider.

### IAM Configuration

**IAM Role:** `GitHubActions-ECR-PushRole`

The role trust policy restricts access to the intended GitHub repository and `main` branch, with the audience:

```text
sts.amazonaws.com
```

### IAM Permissions

The role has permissions required for:

- `ecr:GetAuthorizationToken`
- `ecr:BatchCheckLayerAvailability`
- `ecr:InitiateLayerUpload`
- `ecr:UploadLayerPart`
- `ecr:CompleteLayerUpload`
- `ecr:PutImage`

Image publishing permissions are scoped to the project's ECR repository, while the authorization token action requires `Resource: "*"`.

The workflow uses the GitHub repository variable:

```text
AWS_ROLE_ARN
```

**Security benefit:** No long-lived AWS access keys are stored in GitHub for this workflow. GitHub obtains temporary AWS credentials through OIDC federation.

---

## 10. AWS Deployment

### AWS Resources

**Region:** `ap-southeast-1` — Singapore

| AWS Resource | Configuration |
|---|---|
| Amazon ECR | `aws-devsecops-pipeline` |
| ECS Cluster | `devsecops-cluster` |
| ECS Service | `devsecops-service` |
| Task Definition | `devsecops-task` |
| Container | `devsecops-app` |
| Container Port | `5000` |
| CloudWatch Log Group | `/ecs/devsecops-task` |
| Launch Type | Fargate |
| CPU | 256 |
| Memory | 512 MiB |
| Operating System | Linux |
| Architecture | X86_64 |

### ECS Container Configuration

- Read-only root filesystem enabled.
- Non-root container execution.
- CloudWatch logging enabled.
- ECS Exec disabled.
- Deployment circuit breaker and rollback enabled.
- Existing ECS execution role reused.

### Network Configuration

The deployment uses existing VPC and subnet resources.

| Network Setting | Configuration |
|---|---|
| Subnet Type | Public |
| Public IP | Enabled |
| Inbound | TCP 5000 from administrator public IP |
| Outbound | TCP 443 to `0.0.0.0/0` |

> **Architecture limitation:** This is a cost-conscious portfolio deployment, not a production network design. The application uses a public IP and does not have an HTTPS Application Load Balancer. A private-subnet architecture with appropriate egress and HTTPS termination is a potential future improvement.

### Deployment Verification

The ECS deployment was successfully verified.

| Verification | Result |
|---|---|
| ECS Service Status | ACTIVE |
| Desired Tasks | 1 |
| Running Tasks | 1 |
| Pending Tasks | 0 |
| Deployment Rollout | COMPLETED |
| Application Endpoint | HTTP 200 |
| Health Endpoint | Healthy |
| CloudWatch Logs | Verified |

The verified task definition was revision 5 at project completion. Task revisions and public IP addresses may change during future deployments.

---

## 11. Terraform Infrastructure

Terraform configuration is maintained in the `terraform/` directory.

| File | Purpose |
|---|---|
| `terraform.tf` | Terraform and provider requirements |
| `providers.tf` | AWS provider configuration |
| `variables.tf` | Input variables |
| `main.tf` | AWS data sources and managed resources |
| `outputs.tf` | Terraform outputs |
| `.terraform.lock.hcl` | Provider dependency lock file |

The configuration references existing VPC, subnet, security group, and ECS execution role resources. Selected ECR and ECS resources are managed through Terraform.

### Terraform Validation

Run from the repository root:

```powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

Apply only after reviewing the plan:

```powershell
terraform -chdir=terraform apply
```

> **Important:** The original deployment resources were imported into Terraform state. A fresh clone does not include that local state. Do not run `terraform apply` from an empty state without first planning the resource adoption/import process. Otherwise, Terraform may attempt to create duplicate resources or modify existing infrastructure.

### Terraform State Security

The following are excluded from Git:

```gitignore
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
crash.log
crash.*.log
```

Terraform state may contain sensitive infrastructure information. For long-term or collaborative use, consider a secure remote backend with encryption, access control, and state locking.

---

## 12. Reproduction Guide

To reproduce or adapt the project:

1. Install Git, Docker, AWS CLI, and Terraform.
2. Configure AWS CLI credentials for local administration.
3. Review the resource IDs in `terraform/main.tf`.
4. Update VPC, subnet, security group, and IAM role references for the target AWS environment.
5. Configure GitHub OIDC federation and a least-privilege IAM role.
6. Set the GitHub repository variable `AWS_ROLE_ARN`.
7. Confirm the AWS region, account ID, ECR repository name, and image URI.
8. Initialize Terraform and import existing resources where applicable.
9. Run Terraform validation, planning, and Checkov.
10. Execute the GitHub Actions pipeline.
11. Verify the image in Amazon ECR.
12. Deploy or update the ECS task definition and service.
13. Test the application and health endpoints.
14. Verify application logs in CloudWatch.

**Never commit AWS credentials, `.env` files, Terraform state, or other secrets to GitHub.**

---

## 13. Cost Management

AWS resources may continue generating charges while the project is idle.

Potential cost sources include:

- ECS Fargate tasks.
- CloudWatch log ingestion and storage.
- Retained ECR images and storage.
- Other AWS resources associated with the deployment.

### Pause the Application

To preserve the project while reducing compute costs:

- Set ECS service desired count to `0`.
- Retain the ECR repository and GitHub source code.
- Review CloudWatch log retention.
- Review AWS Billing and Cost Explorer.

### Permanent Cleanup

Before removing resources:

1. Review Terraform state.
2. Review the Terraform destruction plan.
3. Identify resources managed by Terraform.
4. Identify shared or externally managed resources.
5. Back up Terraform state.

Do not delete shared VPCs, subnets, security groups, IAM roles, or other resources that may support unrelated workloads.

---

## 14. Limitations and Future Improvements

The current Version 1.0 implementation is complete for portfolio demonstration.

Potential future enhancements include:

| Area | Improvement |
|---|---|
| CI/CD | Automate ECS deployment after successful ECR publishing |
| Network Security | Move ECS tasks into private subnets |
| HTTPS | Add an Application Load Balancer and managed certificate |
| Monitoring | Add CloudWatch alarms and notifications |
| Reliability | Test deployment rollback and recovery |
| Terraform | Introduce a secure remote state backend |
| Security | Reassess documented Checkov exceptions |

These are future enhancements and are not currently implemented in Version 1.0.

---

## 15. Project Completion

### Final Project Status

<p align="center">
  <img src="https://img.shields.io/badge/Status-Completed-success?style=for-the-badge" alt="Completed"/>
</p>

This project demonstrates practical experience in:

- DevSecOps and CI/CD pipeline implementation.
- Automated application and infrastructure security scanning.
- Docker containerization and hardening.
- AWS IAM and OIDC federation.
- Infrastructure as Code using Terraform.
- Amazon ECR and ECS Fargate deployment.
- CloudWatch logging and application verification.

**Final GitHub Actions run:** Successful  
**Final documented commit:** `d1bccde`  
**Project version:** 1.0

---

<p align="center">
  <strong>AWS DevSecOps CI/CD Pipeline</strong>
  <br/>
  <sub>Completed Portfolio Project — Version 1.0</sub>
</p>

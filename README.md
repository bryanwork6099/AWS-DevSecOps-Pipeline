# AWS DevSecOps CI/CD Pipeline

A portfolio project demonstrating secure application delivery on AWS
using GitHub Actions, Docker, Terraform, Checkov, Trivy, Gitleaks,
Amazon ECR, Amazon ECS Fargate, IAM OIDC federation, and CloudWatch.

> **Project status:** Version 1.0 --- completed and deployed
> successfully\
> **AWS Region:** `ap-southeast-1` (Singapore)\
> **Repository:**
> https://github.com/bryanwork6099/AWS-DevSecOps-Pipeline

## 1. Project overview

This project implements a security-focused CI/CD workflow for a
containerized Python Flask application. On pushes to `main` and pull
requests targeting `main`, GitHub Actions runs infrastructure and
application security checks, builds the Docker image, and scans it for
vulnerabilities.

For pushes to `main`, the workflow authenticates to AWS using GitHub's
OIDC identity provider and a restricted IAM role, then publishes the
image to Amazon ECR.

The application is deployed separately on Amazon ECS using AWS Fargate.
Terraform manages the selected AWS infrastructure resources, while
Checkov scans the Terraform configuration for security
misconfigurations.

### Project goals

-   Integrate security checks into the CI/CD workflow.
-   Detect exposed secrets before application delivery.
-   Scan application dependencies, the filesystem, and the Docker image.
-   Scan Terraform infrastructure configuration for security issues.
-   Authenticate GitHub Actions to AWS without storing long-lived AWS
    access keys in GitHub.
-   Publish immutable container images to Amazon ECR.
-   Run a hardened container on Amazon ECS Fargate.
-   Manage selected infrastructure resources through Terraform.
-   Send container logs to Amazon CloudWatch.

## 2. Architecture

``` text
Developer
   |
   v
GitHub repository
   |
   v
GitHub Actions
   |
   +--> Checkov: Terraform security scan
   |
   +--> Gitleaks: secret detection
   |
   +--> Trivy: filesystem scan
   |
   +--> Docker build
   |
   +--> Trivy: image vulnerability scan
   |
   +--> GitHub OIDC -> AWS IAM role
   |
   +--> Amazon ECR: publish image (push to main only)
                              |
                              v
                     Amazon ECS Fargate
                              |
                              v
                     Amazon CloudWatch Logs
```

**Deployment distinction:** The current GitHub Actions workflow builds,
scans, and publishes images to ECR. ECS Fargate deployment was
provisioned and verified separately using Terraform and the AWS
console/CLI. The workflow does not currently perform an automatic ECS
service update after each image push.

## 3. Technology stack

  -----------------------------------------------------------------------
  Area                    Technology              Purpose
  ----------------------- ----------------------- -----------------------
  Application             Python, Flask           Simple HTTP application
                                                  and health endpoint

  Containerization        Docker                  Package the application
                                                  and runtime

  CI/CD                   GitHub Actions          Automate validation,
                                                  security scanning,
                                                  build, and image
                                                  publishing

  Secret detection        Gitleaks                Detect accidentally
                                                  committed secrets

  Vulnerability scanning  Trivy                   Scan filesystem and
                                                  container image
                                                  vulnerabilities

  IaC security            Checkov                 Detect Terraform
                                                  security
                                                  misconfigurations

  Infrastructure as Code  Terraform               Manage selected AWS
                                                  resources

  Container registry      Amazon ECR              Store Docker images

  Container runtime       Amazon ECS Fargate      Run the container
                                                  without managing EC2
                                                  hosts

  Identity                AWS IAM and GitHub OIDC Federated, short-lived
                                                  AWS credentials

  Logging                 Amazon CloudWatch Logs  Collect
                                                  application/container
                                                  logs
  -----------------------------------------------------------------------

## 4. Repository structure

``` text
AWS-DevSecOps-Pipeline/
├── app/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_main.py
├── terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tf
│   └── variables.tf
├── .github/
│   └── workflows/
│       └── security.yml
├── .gitleaks.toml
├── .dockerignore
├── .gitignore
├── Dockerfile
├── README.md
└── requirements.txt
```

Terraform's local `.terraform/` directory and state files are
intentionally excluded from Git.

## 5. Application

The Flask application exposes two endpoints:

  -------------------------------------------------------------------------
  Endpoint                Purpose                 Expected result
  ----------------------- ----------------------- -------------------------
  `/`                     Application information JSON response showing the
                                                  application is running

  `/health`               Health check            HTTP 200 with
                                                  `{"status": "healthy"}`
  -------------------------------------------------------------------------

The application listens on port `5000`.

### Run locally

Install the Python dependencies:

``` powershell
python -m pip install -r requirements.txt
```

Run the Flask application:

``` powershell
python app/main.py
```

Test the endpoints from another PowerShell window:

``` powershell
Invoke-RestMethod http://localhost:5000/
Invoke-RestMethod http://localhost:5000/health
```

## 6. Docker container hardening

The Docker image uses `python:3.13-slim` and includes several runtime
hardening measures:

-   Installs available Debian security updates during the image build.
-   Installs only the Python application dependencies.
-   Removes pip from the final runtime image after dependency
    installation.
-   Runs the application as a dedicated non-root user (`appuser`).
-   Uses a read-only root filesystem when deployed in ECS.
-   Defines a Docker health check against `/health`.
-   Uses Gunicorn as the production WSGI server.
-   Configures Gunicorn's worker temporary directory as `/dev/shm` so it
    can operate with the ECS read-only root filesystem.

Build and run locally:

``` powershell
docker build -t devsecops-app:local .
docker run --rm -p 5000:5000 devsecops-app:local
```

Test the container:

``` powershell
Invoke-RestMethod http://localhost:5000/
Invoke-RestMethod http://localhost:5000/health
```

The Trivy image scan was configured to fail on HIGH and CRITICAL
findings while ignoring unfixed findings. This does not mean all
vulnerabilities are absent: unfixed findings are filtered from the
pipeline's failure condition and should still be reviewed periodically.

## 7. CI/CD workflow

Workflow file: `.github/workflows/security.yml`

The workflow runs for:

-   Pushes to the `main` branch.
-   Pull requests targeting the `main` branch.

### Pipeline stages

1.  **Checkout repository** --- retrieves the source code.
2.  **Checkov Terraform scan** --- scans the `terraform/` directory
    using `bridgecrew/checkov:3.4.11`.
3.  **Gitleaks secret detection** --- checks the repository for exposed
    secrets.
4.  **Trivy filesystem scan** --- scans the repository filesystem for
    vulnerabilities and misconfigurations.
5.  **Docker image build** --- builds the Flask application image.
6.  **Trivy image scan** --- scans the built image for HIGH and CRITICAL
    vulnerabilities.
7.  **AWS OIDC authentication** --- on pushes to `main`, assumes the
    configured AWS IAM role.
8.  **Amazon ECR login** --- authenticates Docker to ECR.
9.  **Push image to ECR** --- tags the image with the full Git commit
    SHA and pushes it to the repository.

AWS authentication and ECR publishing are conditional on a push to
`main`. Pull requests run the security checks and image build but do not
publish to ECR.

### Security scan settings

The Trivy steps use:

-   `severity: HIGH,CRITICAL`
-   `ignore-unfixed: true`
-   `exit-code: '1'`

The workflow therefore fails when the configured scan detects applicable
HIGH or CRITICAL findings. Review the complete scan output and
understand the effect of `ignore-unfixed` when interpreting results.

### Checkov result

The final local Checkov scan reported:

  Result                                 Count
  ------------------------------------ -------
  Passed                                    10
  Failed                                     0
  Skipped with documented exceptions         4

The four skips are documented risk/cost decisions in the Terraform
configuration:

-   **CKV_AWS_136:** ECR uses AWS-managed AES-256 encryption rather than
    a customer-managed KMS key to avoid additional key costs.
-   **CKV_AWS_224:** ECS Exec is intentionally disabled; application
    logs are sent to CloudWatch using the `awslogs` driver.
-   **CKV_AWS_65:** Container Insights is disabled to limit monitoring
    costs for this small portfolio workload.
-   **CKV_AWS_333:** Public IP assignment is retained for this low-cost
    deployment. Inbound application access is restricted by the security
    group to the administrator's public IP. A
    private-subnet/load-balancer architecture is deferred.

Skipped checks are documented exceptions, not passing checks. Reassess
these decisions before using the architecture for production workloads.

## 8. GitHub-to-AWS authentication with OIDC

GitHub Actions authenticates to AWS through the GitHub OIDC provider and
the IAM role `GitHubActions-ECR-PushRole`.

The role trust policy is restricted to the intended GitHub repository
and `main` branch subject, with the audience `sts.amazonaws.com`.

The role's permissions are limited to:

-   `ecr:GetAuthorizationToken` for registry authentication.
-   Required image upload and publication actions on the project's ECR
    repository.

This avoids storing long-lived AWS access keys as GitHub repository
secrets. The workflow reads the role ARN from the GitHub repository
variable `AWS_ROLE_ARN`.

Before reusing this setup in another repository, update the OIDC trust
policy, repository subject, role ARN, region, and ECR repository
details.

## 9. AWS deployment

### AWS resources

The project was deployed in `ap-southeast-1` (Singapore).

  Resource                               Name / configuration
  -------------------------------------- --------------------------
  ECR repository                         `aws-devsecops-pipeline`
  ECS cluster                            `devsecops-cluster`
  ECS service                            `devsecops-service`
  Task definition family                 `devsecops-task`
  Container name                         `devsecops-app`
  Container port                         `5000`
  CloudWatch log group                   `/ecs/devsecops-task`
  ECS launch type                        Fargate
  Task CPU / memory                      256 CPU units / 512 MiB
  Task operating system / architecture   Linux / X86_64

The ECS task uses the existing `ecsTaskExecutionRole`. No separate
application task role is configured for this simple application.

### Container settings

-   `readonlyRootFilesystem` is enabled.
-   The container runs as a non-root user.
-   The container uses port `5000`.
-   Container logs are sent to `/ecs/devsecops-task` using the `awslogs`
    log driver.
-   ECS Exec is disabled.
-   The ECS service has a deployment circuit breaker with rollback
    enabled.

### Network configuration and limitations

The initial portfolio deployment uses existing VPC/subnet resources and
a security group rather than creating a new network. The task receives a
public IP in public subnets. Inbound TCP port `5000` is restricted to
the administrator's public IP address, and outbound TCP `443` is
allowed.

This is a cost-conscious demonstration setup, not a production reference
architecture. The public-IP design, lack of an HTTPS load balancer, and
administrator-IP allow-list should be reconsidered before broader use. A
task public IP can change after replacement or redeployment.

### Deployment verification

The deployed service was verified with:

-   ECS service status `ACTIVE`.
-   Desired task count `1`.
-   Running task count `1`.
-   Pending task count `0`.
-   Deployment rollout status `COMPLETED`.
-   Successful HTTP response from `/`.
-   Successful health response from `/health`.
-   Gunicorn startup and HTTP 200 request entries in CloudWatch Logs.

The verified task definition was revision 5 at the time of project
completion. Runtime IP addresses and task revisions can change over
time.

## 10. Terraform

Terraform configuration is stored in `terraform/`:

-   `terraform.tf` --- Terraform and AWS provider version requirements.
-   `providers.tf` --- AWS provider configuration.
-   `variables.tf` --- configurable deployment variables.
-   `main.tf` --- data sources and managed ECR/ECS resources.
-   `outputs.tf` --- useful Terraform outputs.
-   `.terraform.lock.hcl` --- provider dependency lock file.

The configuration references existing VPC, subnet, security group, and
ECS execution role resources through data sources. It manages selected
resources including the ECR repository, ECS cluster, task definition,
and ECS service.

### Validate and plan

From the repository root:

``` powershell
terraform -chdir=terraform init
terraform -chdir=terraform fmt -check
terraform -chdir=terraform validate
terraform -chdir=terraform plan
```

Review a plan carefully before applying it:

``` powershell
terraform -chdir=terraform apply
```

Do not run `apply` against an unfamiliar or newly initialized state. The
existing resources were imported into Terraform state during this
project. A new clone does not contain that local state, and blindly
applying from an empty state can attempt to create duplicate resources
or change existing infrastructure.

### Terraform state handling

The following files/directories are intentionally ignored by Git:

-   `.terraform/`
-   `*.tfstate`
-   `*.tfstate.*`
-   `*.tfplan`

Terraform state may contain sensitive infrastructure information. For
collaborative or long-term use, configure a secure remote backend with
appropriate access control, encryption, and state locking. Back up state
before making backend or state-management changes.

## 11. Reproduce or adapt the project

Before running this project in another AWS account or region:

1.  Install Git, Docker, AWS CLI, and Terraform.
2.  Configure AWS CLI credentials for local administrative operations.
3.  Review and update the resource IDs in `terraform/main.tf` to match
    the target environment.
4.  Review the security group, subnet, VPC, and IAM execution role
    references.
5.  Configure the GitHub OIDC identity provider and a least-privilege
    IAM role.
6.  Set the GitHub repository variable `AWS_ROLE_ARN`.
7.  Confirm the ECR repository name, AWS region, and account-specific
    image URI used by the workflow and task definition.
8.  Initialize Terraform and import existing resources when adopting an
    already-deployed environment.
9.  Run Terraform validation, planning, and Checkov scanning.
10. Run the GitHub Actions workflow and verify the published ECR image.
11. Deploy or update the ECS task definition/service and verify both
    application endpoints.

Never commit AWS credentials, Terraform state, `.env` files, or other
secrets to the repository.

## 12. Cost management and cleanup

AWS resources may incur charges while the project is idle. In
particular, Fargate tasks, CloudWatch log ingestion/storage, and other
retained AWS resources may create ongoing costs.

To pause the application while retaining the project:

-   Set the ECS service desired count to `0`.
-   Keep the source code and ECR repository if you want to preserve the
    image.
-   Review CloudWatch log retention.
-   Review the AWS Billing console and Cost Explorer for other billable
    resources.

To permanently remove the deployment, first review Terraform state and
the destruction plan. Understand which resources are managed by
Terraform and which are shared/external resources. Do not delete shared
VPCs, subnets, security groups, IAM roles, or other resources that may
be used by unrelated workloads. Back up state before any teardown.

## 13. Known limitations and future improvements

The Version 1.0 project is complete for portfolio demonstration, with
the following improvements intentionally left for a future iteration:

-   Automate ECS task-definition registration and service deployment
    after a successful ECR push.
-   Introduce HTTPS through an Application Load Balancer and a managed
    certificate.
-   Move ECS tasks into private subnets and use appropriate egress
    infrastructure.
-   Add CloudWatch alarms and notifications.
-   Add deployment/rollback testing and operational runbooks.
-   Consider a remote Terraform backend and stronger separation of
    environments.
-   Revisit the four documented Checkov exceptions as requirements and
    budget change.

These are future enhancements, not claims that the current project
already implements them.

## 14. Project completion summary

Version 1.0 demonstrates a complete security-focused application build
and image-publishing workflow, AWS OIDC federation, Terraform-managed
AWS resources, and a separately deployed and verified ECS Fargate
application.

The final GitHub Actions run for commit `d1bccde` completed
successfully. The project is suitable as a cloud security / DevSecOps
portfolio demonstration, provided its deployment limitations and
documented security trade-offs are understood.

------------------------------------------------------------------------

**Author:** Project portfolio\
**Project:** AWS DevSecOps CI/CD Pipeline\
**Status:** Completed --- Version 1.0

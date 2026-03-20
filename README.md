# 2048 Game - AWS CI/CD Portfolio Project

This repository demonstrates a fully automated CI/CD pipeline for deploying a containerized 2048 game application on AWS using Infrastructure as Code(Terraform), Container Orchestration Service(ECS) and continuous deployment using GitHub Actions.

## Technology Stack

- **Containerization:** Docker
- **Container Orchestration:** AWS ECS Fargate
- **Infrastructure as Code:** Terraform
- **Image Registry:** AWS ECR
- **Load Balancing:** AWS Application Load Balancer
- **Networking:** AWS VPC
- **CI/CD:** GitHub Actions
- **Authentication:** AWS IAM + OIDC
- **State Management:** S3 + Server-Side Encryption

### Core Components & Design Rationale

1. **VPC (Virtual Private Cloud):**
    * **Role:** Provides network isolation and control.
    * **Implementation:** Spans two Availability Zones (`eu-west-1a`, `eu-west-1b`) for high availability. Public subnets (10.0.1.0/24, 10.0.2.0/24) host the ALB and ECS tasks. DNS support is enabled to allow hostname resolution within the VPC.
    * **Benefit:** Multi-AZ deployment ensures the application remains available even if one AZ experiences an outage.

2. **Application Load Balancer (ALB):**
    * **Role:** Distributes incoming traffic across ECS tasks running the 2048 game application.
    * **Implementation:** Deployed in public subnets with a target group configured for HTTP/80. Health checks are configured to monitor task health with a 30-second interval, ensuring only healthy instances receive traffic.
    * **Security:** Dedicated security group that accepts inbound HTTP traffic from the internet (0.0.0.0/0) and allows unrestricted outbound traffic.

3. **ECS Fargate (Elastic Container Service):**
    * **Role:** Orchestrates and runs the containerized 2048 game application without requiring infrastructure management.
    * **Implementation:**
        * **ECS Cluster:** Named `2048-game-cluster` provides the logical grouping.
        * **Task Definition:** Specifies container configuration including Docker image URI, CPU (256), memory (512 MB), and port mappings (port 80).
        * **ECS Service:** Maintains the desired number of running task instances (default: 1), registers tasks with the ALB target group, and handles automatic restarts on failure.
    * **Advantage:** Eliminates the need to provision and manage EC2 instances, reducing operational overhead.

4. **ECR (Elastic Container Registry):**
    * **Role:** Serves as the private Docker image registry for the application.
    * **Implementation:** The CI/CD pipeline builds Docker images locally, tags them with the commit SHA (7-character short hash), and pushes them to ECR. Images are referenced by their URI in the ECS task definition.
    * **Security:** Integrated with IAM roles to control who can push/pull images.

5. **Security Groups:**
    * **ALB Security Group:**
        * Allows inbound HTTP traffic on port 80 from anywhere (0.0.0.0/0).
        * Permits all outbound traffic.
    * **ECS Security Group:**
        * Restricts inbound traffic to port 80 from the ALB security group only, creating a secure boundary.
        * Allows all outbound traffic for pulling images and external communication.

## CI/CD Automation with GitHub Actions

The deployment process is fully automated using two independent GitHub Actions workflows, following the principle of separating infrastructure and application deployments.

### 1. Infrastructure Pipeline (`deploy-infra.yml`)

**Trigger:** Activates on any push to the `terraform/` directory on the `main` branch.

**Purpose:** Manages the complete lifecycle of AWS infrastructure using Terraform.

**Process:**
1. **Terraform Init:** Initializes the Terraform working directory and downloads required providers. Uses remote state stored in S3 with encryption enabled.
2. **Terraform Plan:** Generates an execution plan showing what resources will be created, modified, or destroyed. The plan is saved to a file for review and ensures predictability.
3. **Terraform Apply:** Executes the plan, provisioning or updating all AWS resources (VPC, ALB, ECS cluster, security groups, etc.).

**Key Features:**
* **State Management:** Terraform state is stored remotely in S3 with server-side encryption. This enables team collaboration and prevents state corruption.
* **Path-Triggered:** Only runs when files in the `terraform/` directory change, avoiding unnecessary executions.
* **OIDC Authentication:** Uses AWS OIDC provider for secure, keyless authentication. The GitHub Actions workflow assumes an IAM role without requiring AWS access keys.

### 2. Application Pipeline (`build-and-push.yml`)

**Trigger:** Activates on any push to the `app/` directory on the `main` branch or manual workflow dispatch.

**Purpose:** Builds, pushes, and deploys the containerized application without modifying infrastructure.

**Process:**

1. **Build Docker Image:**
    * Builds a Docker image from the `app/` directory.
    * Tags the image with the commit SHA (7-character short hash) for unique identification and traceability.

2. **Push to ECR:**
    * Authenticates to the AWS ECR registry using OIDC.
    * Tags the image with the ECR repository URI.
    * Pushes the image to the ECR repository.

3. **Deploy to ECS:**
    * Retrieves the current ECS task definition.
    * Updates the container image URI to point to the newly pushed image in ECR.
    * Registers a new task definition revision.
    * Updates the ECS service to use the new task definition revision.
    * Uses `--force-new-deployment` to ensure ECS immediately stops the old task and starts the new one.

4. **Conditional Deployment:**
    * Checks if the ECS service exists before attempting deployment. This prevents failures if the infrastructure hasn't been deployed yet.

**Key Features:**
* **Commit-Based Image Tagging:** Using the commit SHA as the image tag enables quick rollbacks by re-deploying a previous image tag.
* **Path-Triggered:** Only runs when files in the `app/` directory change, optimizing CI/CD efficiency.
* **OIDC Authentication:** Like the infrastructure pipeline, uses keyless authentication via AWS OIDC.
* **Separation of Concerns:** Infrastructure and application deployments are completely independent, allowing developers to deploy code changes without touching infrastructure.

## Key Architectural Decisions

1. **Fargate vs EC2:** Fargate was chosen to eliminate the operational overhead of managing EC2 instances and patching. This reduces the security surface area and operational complexity.

2. **Separated CI/CD Pipelines:** By separating infrastructure and application deployments, your team can:
    * Deploy code changes without infrastructure risk.
    * Ensure infrastructure stability independent of application updates.
    * Optimize build times by only running relevant workflows.

3. **Commit SHA Image Tagging:** Tagging images with commit SHAs provides:
    * Exact traceability between running code and git commits.
    * Easy rollback capability by re-deploying a previous image tag.
    * Prevention of image tag collisions.

4. **OIDC Authentication:** Using OIDC for GitHub Actions eliminates the need to manage AWS access keys in GitHub Secrets, significantly improving security posture.

## Monitoring and Maintenance

- **CloudWatch Logs:** ECS tasks log to CloudWatch. Monitor application health via the ECS console.
- **ALB Metrics:** Monitor request counts, response times, and unhealthy host counts via CloudWatch.
- **Cost Optimization:** ECS Fargate charges are based on vCPU-hours and memory-hours. The current configuration (256 vCPU, 512 MB memory) is cost-effective for this application.

## Scalability

To scale the application to handle more traffic:
1. Increase the `desired_count` in the ECS service from 1 to your target number of replicas.
2. The ALB automatically distributes traffic across all healthy tasks.
3. Consider implementing auto-scaling policies based on CPU or memory metrics.

---

**Project Structure:**
- `app/` - Application source code and Dockerfile
- `terraform/` - Infrastructure as Code (VPC, ALB, ECS, IAM, Security Groups)
- `.github/workflows/` - GitHub Actions CI/CD pipeline definitions

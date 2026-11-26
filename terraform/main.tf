# Existing VPC
data "aws_vpc" "existing" {
  id = "vpc-06a8f1e05a7427178"
}

# Existing ECS subnets
data "aws_subnet" "subnet_a" {
  id = "subnet-0abb1382af1f436d4"
}

data "aws_subnet" "subnet_b" {
  id = "subnet-078c50e824a1f7984"
}

data "aws_subnet" "subnet_c" {
  id = "subnet-072e7242a10cb96ff"
}

# Existing ECS security group
data "aws_security_group" "ecs" {
  id = "sg-00473560d63e6bd74"
}

# Existing ECS task execution role
data "aws_iam_role" "ecs_execution" {
  name = "ecsTaskExecutionRole"
}


# Existing ECR repository
resource "aws_ecr_repository" "app" {
#checkov:skip=CKV_AWS_136:Using AWS-managed AES-256 encryption at rest to avoid additional customer-managed KMS key costs for this portfolio project.
  name                 = "aws-devsecops-pipeline"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Existing ECS cluster
resource "aws_ecs_cluster" "app" {
#checkov:skip=CKV_AWS_224:ECS Exec is not enabled for this project. Application logs are sent to CloudWatch using awslogs, and interactive ECS Exec access is intentionally disabled.
#checkov:skip=CKV_AWS_65:Container Insights is disabled to avoid additional monitoring costs for this small portfolio workload. CloudWatch application logs remain enabled.
  name = "devsecops-cluster"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  configuration {
    execute_command_configuration {
      logging = "DEFAULT"
    }
  }

  tags = {
    Name        = "devsecops-cluster"
    Environment = "portfolio"
    Project     = "AWS-DevSecOps-Pipeline"
  }
}

# Existing ECS task definition
resource "aws_ecs_task_definition" "app" {
  family                   = "devsecops-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"

  execution_role_arn = data.aws_iam_role.ecs_execution.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([

    {
      name                   = "devsecops-app"
      image                  = "366554472163.dkr.ecr.ap-southeast-1.amazonaws.com/aws-devsecops-pipeline@sha256:3a2f394fe61e69858fb03bba9c08999bbc0bc4b258add5e163ea510ba64dd27e"
      cpu                    = 0
      essential              = true
      readonlyRootFilesystem = true

      environment      = []
      environmentFiles = []
      mountPoints      = []
      volumesFrom      = []
      ulimits          = []
      systemControls   = []

      portMappings = [
        {
          containerPort = 5000
          hostPort      = 5000
          protocol      = "tcp"
          name          = "devsecops-app-5000-tcp"
          appProtocol   = "http"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"

        options = {
          "awslogs-group"         = "/ecs/devsecops-task"
          "awslogs-create-group"  = "true"
          "awslogs-region"        = "ap-southeast-1"
          "awslogs-stream-prefix" = "ecs"
        }

        secretOptions = []
      }
    }
  ])
}

# Existing ECS service
resource "aws_ecs_service" "app" {
#checkov:skip=CKV_AWS_333:Public IP is intentionally enabled for this low-cost portfolio deployment. Inbound TCP 5000 is restricted to the administrator's public IP through the ECS security group. A private subnet and load balancer architecture is deferred.
  name            = "devsecops-service"
  cluster         = aws_ecs_cluster.app.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  platform_version = "LATEST"

  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets = [
      data.aws_subnet.subnet_a.id,
      data.aws_subnet.subnet_b.id,
      data.aws_subnet.subnet_c.id
    ]

    security_groups = [
      data.aws_security_group.ecs.id
    ]

    assign_public_ip = true
  }

  enable_ecs_managed_tags = true
  enable_execute_command  = false

  deployment_controller {
    type = "ECS"
  }

  scheduling_strategy = "REPLICA"
  propagate_tags      = "NONE"

  availability_zone_rebalancing = "ENABLED"
}
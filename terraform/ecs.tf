
# There are three different parts of an ECS deployment: a cluster, a task definition, and a service.

# The cluster is easy to set up - not a lot going on here
resource "aws_ecs_cluster" "my_cluster" {
  name = "MyCluster"
}

# I've decided to use the FARGATE deployment option to make things as simple as possible. I don't want
# to have to fool around with EC2 instances, auto-scaling groups, etc.
resource "aws_ecs_task_definition" "mytask" {
  family                      = "mytask"
  requires_compatibilities    = ["FARGATE"]
  network_mode                = "awsvpc" # all fargate tasks are awsvpc
  execution_role_arn          = aws_iam_role.task_execution_iam_role.arn # the IAM role used to execute the task
  task_role_arn               = aws_iam_role.ecs_task_iam_role.arn # the IAM role for the task itself
  cpu                         = 512
  memory                      = 1024
  container_definitions       = jsonencode([
    {
      name      = "my-docker-image"
      image     = "${aws_ecr_repository.myrepo.repository_url}:latest"
      essential = true
      portMappings = [
        {
          containerPort = 3000
          # For task definitions that use the awsvpc network mode, only specify the containerPort.
          # The hostPort can be left blank or it must be the same value as the containerPort.
        }
      ]
      logConfiguration: {
        logDriver: "awslogs",
        options: {
          "awslogs-group": "/ecs/mytask",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "ecs"
          "awslogs-create-group": "true",
        }
      }
    }
  ])
}

# You can set the 
resource "aws_ecs_service" "myservice" {
  name            = "myservice"
  cluster         = aws_ecs_cluster.my_cluster.id
  task_definition = aws_ecs_task_definition.mytask.arn
  desired_count   = 1  # The number of containers to create. Set this to zero to effectively turn off the service.
  launch_type     = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.my_target_group.arn
    container_name   = "my-container-name"
    container_port   = 3000
  }

  # Note that these containers are running in the private subnets. They can connect to the outside world
  # (and to AWS services) through NAT gateways.
  network_configuration {
    subnets = [for subnet in aws_subnet.private_subnets : subnet.id]
    security_groups = [aws_security_group.ecs_service_sg.id]
  }
}
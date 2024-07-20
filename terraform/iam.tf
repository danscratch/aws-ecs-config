
##################################################################
# Role for the ECS execution role
# We need to create this special role instead of using the default (ecsTaskExecutionRole) because
# we are adding a CloudWatch log group, and the default role doesn't have the ability to do that.
resource "aws_iam_role" "task_execution_iam_role" {
  name               = "task_execution_iam_role"

  assume_role_policy = <<ROLE_DEFINITION
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Principal":{
            "Service":[
               "ecs-tasks.amazonaws.com"
            ]
         },
         "Action":"sts:AssumeRole"
      }
   ]
}
ROLE_DEFINITION
}

data "aws_iam_policy_document" "cloudwatch_create_logs" {
  statement {
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch_create_logs" {
  name        = "cloudwatch-create-logs"
  description = "Allow creation of CloudWatch logs"
  policy      = data.aws_iam_policy_document.cloudwatch_create_logs.json
}

# Give the role the ability to create CloudWatch logs
resource "aws_iam_role_policy_attachment" "attach_cloudwatch_create_logs" {
  role       = aws_iam_role.task_execution_iam_role.name
  policy_arn = aws_iam_policy.cloudwatch_create_logs.arn
}

# Add the same permissions that the ecsTaskExecutionRole has
resource "aws_iam_role_policy_attachment" "attach_ecs_task_execution_role_policy" {
  role       = aws_iam_role.task_execution_iam_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

##################################################################
# Role for the ECS task
# By adding policies to this role, you give your ECS task access to different AWS services.
resource "aws_iam_role" "ecs_task_iam_role" {
  name               = "ecs_task_iam_role"

  assume_role_policy = <<ROLE_DEFINITION
{
   "Version":"2012-10-17",
   "Statement":[
      {
         "Effect":"Allow",
         "Principal":{
            "Service":[
               "ecs-tasks.amazonaws.com"
            ]
         },
         "Action":"sts:AssumeRole"
      }
   ]
}
ROLE_DEFINITION
}

resource "aws_iam_policy" "secrets_policy" {
  name = "secrets_policy"
  path = "/"
  description = "Access permissions for the app"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "VisualEditor0",
        "Effect": "Allow",
        "Action": "secretsmanager:GetSecretValue",
        "Resource": [
          # By putting secret ARNs in here, you can give your ECS instance access to them.
          # You should never put secrets into GitHub – saving them in AWS SecretsManager is a good way to make them
          # available to your app. The arn can be stored in GitHub, since it won't do someone any good without admin
          # access to the account. You should change these ARNs to match whatever secrets you're using.
          "arn:aws:secretsmanager:us-east-1:702123456789:secret:auth/credentials-abcdef",
          "arn:aws:secretsmanager:us-east-1:702123456789:secret:rds!db-abcdefg-abcd-abcd-abcd-abcdefghijkl-abcdef"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_secrets_policy" {
  role       = aws_iam_role.ecs_task_iam_role.name
  policy_arn = aws_iam_policy.secrets_policy.arn
}


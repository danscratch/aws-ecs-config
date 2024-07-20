
# Docker images are stored in DockerHub by default, but I wanted to keep everything in AWS. This
# is also one of the easiest parts of the configuration to set up.
resource "aws_ecr_repository" "myrepo" {
  name                 = "myrepo"
  image_tag_mutability = "MUTABLE"
  force_delete         = false

  image_scanning_configuration {
    scan_on_push = true
  }
}

# Set up a lifecycle policy so that you don't end up with a monotonically increasing repo size
# (and bill).
resource "aws_ecr_lifecycle_policy" "expire_old_images_policy" {
  repository = aws_ecr_repository.myrepo.name

  policy = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire images older than 3 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 3
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

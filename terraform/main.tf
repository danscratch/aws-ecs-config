
provider "aws" {
  region = "us-east-1"
}

terraform {
  backend "s3" {
    # You will have to create this bucket before calling "terraform init"
    bucket = "aws-ec2-config-tfstate"
    key    = "tf/terraform.tfstate"
    region = "us-east-1"
  }
}

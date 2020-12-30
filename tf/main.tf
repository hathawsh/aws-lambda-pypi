terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      # version = "~> 3.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}

resource "aws_cloudwatch_log_group" "pypicloud" {
  name = var.log_group
}

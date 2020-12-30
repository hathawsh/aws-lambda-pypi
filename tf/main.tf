
variable "pypicloud_bucket" {
  type = string
  description = "Name of the S3 bucket where pypi packages are to be stored"
}

variable "region" {
  type = string
}

variable "pypicloud_user" {
  type = string
  description = "Name of the S3 bucket user"
}

variable "log_group" {
  type = string
  description = "CloudWatch log group for access logs"
}

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

# resource "aws_iam_user" "pypicloud" {
#   name = var.pypicloud_user
#   path = "/"
# }

resource "aws_iam_policy" "pypicloud_rw" {
  name = "pypicloud_packages_rw"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:RestoreObject",
        "s3:ListBucket",
        "s3:DeleteObject",
        "s3:GetObjectVersion"
      ],
      "Resource": [
        "arn:aws:s3:::${var.pypicloud_bucket}/*",
        "arn:aws:s3:::${var.pypicloud_bucket}"
      ]
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "pypicloud_xray" {
  name = "pypicloud_xray"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
POLICY
}

# resource "aws_iam_user_policy_attachment" "pypicloud_rw" {
#   user = aws_iam_user.pypicloud.name
#   policy_arn = aws_iam_policy.pypicloud_rw.arn
# }

resource "aws_iam_role" "pypicloud" {
  name = "pypicloud"
  path = "/service-role/"
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "pypicloud_rw" {
  role = aws_iam_role.pypicloud.name
  policy_arn = aws_iam_policy.pypicloud_rw.arn
}

resource "aws_iam_role_policy_attachment" "AWSLambdaBasicExecutionRole" {
  role = aws_iam_role.pypicloud.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "pypicloud_xray" {
  role = aws_iam_role.pypicloud.name
  policy_arn = aws_iam_policy.pypicloud_xray.arn
}

resource "aws_lambda_function" "pypicloud" {
  filename = "../out/lambda_pypicloud.zip"
  source_code_hash = filebase64sha256("../out/lambda_pypicloud.zip")
  function_name = "pypicloud"
  role = aws_iam_role.pypicloud.arn
  handler = "lambda_function.lambda_handler"
  memory_size = "256"
  publish = false
  timeout = "180"
  runtime = "python3.8"

  environment {
    variables = {
      "PYPICLOUD_CONF_REGION" = var.region
      "PYPICLOUD_CONF_SECRET_ID" = "pypicloud_server_ini"
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_s3_bucket" "pypicloud" {
  bucket = var.pypicloud_bucket
  versioning {
    enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "pypicloud" {
  bucket = aws_s3_bucket.pypicloud.id

  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}

resource "aws_secretsmanager_secret" "server_ini" {
  name = "pypicloud_server_ini"
  recovery_window_in_days = 30
  description = "server.ini for pypicloud"
}

resource "aws_secretsmanager_secret_policy" "server_ini" {
  secret_arn = aws_secretsmanager_secret.server_ini.arn
  policy = <<POLICY
{
  "Version" : "2012-10-17",
  "Statement" : [ {
    "Effect" : "Allow",
    "Principal" : {
      "AWS" : "${aws_iam_role.pypicloud.arn}"
    },
    "Action" : "secretsmanager:GetSecretValue",
    "Resource" : "*"
  } ]
}
POLICY
}

resource "aws_secretsmanager_secret" "auth" {
  name = "pypicloud_auth"
  recovery_window_in_days = 30
  description = "pypicloud ACL state"
}

resource "aws_secretsmanager_secret_policy" "auth" {
  secret_arn = aws_secretsmanager_secret.auth.arn
  policy = <<POLICY
{
  "Version" : "2012-10-17",
  "Statement" : [ {
    "Effect" : "Allow",
    "Principal" : {
      "AWS" : "${aws_iam_role.pypicloud.arn}"
    },
    "Action" : [ "secretsmanager:GetSecretValue", "secretsmanager:UpdateSecret" ],
    "Resource" : "*"
  } ]
}
POLICY
}

resource "aws_apigatewayv2_api" "pypicloud" {
  name = "pypicloud"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "pypicloud" {
  api_id = aws_apigatewayv2_api.pypicloud.id
  integration_type = "AWS_PROXY"

  connection_type = "INTERNET"
  // content_handling_strategy = "CONVERT_TO_TEXT"
  // description               = "Lambda example"
  integration_method = "POST"
  integration_uri = aws_lambda_function.pypicloud.arn
  passthrough_behavior = "WHEN_NO_MATCH"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "pypicloud" {
  api_id = aws_apigatewayv2_api.pypicloud.id
  route_key = "$default"
  target = "integrations/${aws_apigatewayv2_integration.pypicloud.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id = aws_apigatewayv2_api.pypicloud.id
  name = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.pypicloud.arn
    format = "$context.identity.sourceIp - - [$context.requestTime] \"$context.httpMethod $context.routeKey $context.protocol\" $context.status $context.responseLength $context.requestId $context.integrationErrorMessage"
  }
}

resource "aws_lambda_permission" "pypicloud" {
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pypicloud.arn
  principal = "apigateway.amazonaws.com"
  source_arn = "${aws_apigatewayv2_api.pypicloud.execution_arn}/*/${aws_apigatewayv2_stage.default.name}"
}

resource "aws_dynamodb_table" "DynamoPackage" {
  name = "DynamoPackage"
  hash_key = "filename"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "filename"
    type = "S"
  }

  attribute {
    name = "name"
    type = "S"
  }

  global_secondary_index {
    hash_key = "name"
    name = "name-index"
    non_key_attributes = []
    projection_type = "ALL"
    read_capacity = 5
    write_capacity = 5
  }
}

resource "aws_dynamodb_table" "PackageSummary" {
  name = "PackageSummary"
  hash_key = "name"
  read_capacity = 5
  write_capacity = 5

  attribute {
    name = "name"
    type = "S"
  }
}

resource "aws_iam_policy" "pypicloud_dynamo" {
  name = "${var.pypicloud_user}_dynamo"
  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VisualEditor0",
      "Effect": "Allow",
      "Action": [
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem",
        "dynamodb:ConditionCheckItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem",
        "dynamodb:PartiQLUpdate",
        "dynamodb:Scan",
        "dynamodb:ListTagsOfResource",
        "dynamodb:Query",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteTable",
        "dynamodb:CreateTable",
        "dynamodb:PartiQLSelect",
        "dynamodb:DescribeTable",
        "dynamodb:PartiQLInsert",
        "dynamodb:GetItem",
        "dynamodb:UpdateTable",
        "dynamodb:GetRecords",
        "dynamodb:PartiQLDelete"
      ],
      "Resource": [
        "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/DynamoPackage/index/*",
        "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/PackageSummary/index/*",
        "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/DynamoPackage",
        "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:table/PackageSummary"
      ]
    },
    {
      "Sid": "VisualEditor1",
      "Effect": "Allow",
      "Action": "dynamodb:ListTables",
      "Resource": "arn:aws:dynamodb:${var.region}:${data.aws_caller_identity.current.account_id}:*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "pypicloud_dynamo" {
  role = aws_iam_role.pypicloud.name
  policy_arn = aws_iam_policy.pypicloud_dynamo.arn
}

resource "aws_cloudwatch_log_group" "pypicloud" {
  name = var.log_group
}

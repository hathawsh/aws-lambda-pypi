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
  name = "pypicloud_dynamo"
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

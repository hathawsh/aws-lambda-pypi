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
        "arn:aws:s3:::${var.package_bucket}/*",
        "arn:aws:s3:::${var.package_bucket}"
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

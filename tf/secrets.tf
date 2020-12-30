resource "aws_secretsmanager_secret" "env" {
  name = "pypicloud_env"
  recovery_window_in_days = 30
  description = "Secret env vars for the pypicloud Lambda function"
}

resource "aws_secretsmanager_secret_policy" "env" {
  secret_arn = aws_secretsmanager_secret.env.arn
  policy = <<POLICY
{
  "Version" : "2012-10-17",
  "Statement" : [ {
    "Effect" : "Allow",
    "Principal" : {
      "AWS" : "${aws_iam_role.pypicloud.arn}"
    },
    "Action" : [ "secretsmanager:GetSecretValue", "secretsmanager:PutSecretValue" ],
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

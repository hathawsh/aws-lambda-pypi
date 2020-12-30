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

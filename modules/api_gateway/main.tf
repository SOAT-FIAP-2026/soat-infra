# ==============================================================================
# Módulo: API Gateway — HTTP API v2
# ==============================================================================
# Cria um HTTP API Gateway com a rota POST /auth integrada à Lambda de auth.
#
# Usa payload_format_version "1.0" para compatibilidade com o tipo
# APIGatewayProxyRequest do Amazon.Lambda.APIGatewayEvents (.NET SDK).
# ==============================================================================

# --- CloudWatch Log Group -----------------------------------------------------
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project_name}-auth-api"
  retention_in_days = var.log_retention_days
}

# --- HTTP API -----------------------------------------------------------------
resource "aws_apigatewayv2_api" "auth" {
  name          = "${var.project_name}-auth-api"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway para autenticação via CPF — dispara Lambda"
}

# --- Stage padrão com auto-deploy --------------------------------------------
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.auth.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gw.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      sourceIp       = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      errorMessage   = "$context.error.message"
    })
  }
}

# --- Integração Lambda proxy --------------------------------------------------
# payload_format_version "1.0" é obrigatório para APIGatewayProxyRequest/.NET
resource "aws_apigatewayv2_integration" "lambda_auth" {
  api_id                 = aws_apigatewayv2_api.auth.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  payload_format_version = "1.0"
}

# --- Rota: POST /auth ---------------------------------------------------------
resource "aws_apigatewayv2_route" "post_auth" {
  api_id    = aws_apigatewayv2_api.auth.id
  route_key = "POST /auth"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_auth.id}"
}

# --- Permissão: API Gateway → Lambda -----------------------------------------
resource "aws_lambda_permission" "allow_api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"

  # source_arn limita invocação apenas às rotas deste API Gateway
  source_arn = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

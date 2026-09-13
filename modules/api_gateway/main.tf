# ==============================================================================
# Módulo: API Gateway — HTTP API v2
# ==============================================================================
# Cria um HTTP API Gateway com a rota POST /auth integrada à Lambda de auth.
#
# Usa payload_format_version "1.0" para compatibilidade com o tipo
# APIGatewayProxyRequest do Amazon.Lambda.APIGatewayEvents (.NET SDK).
#
# Segurança aplicada:
#   - Throttling no stage para prevenir DoS e enumeração de CPF por brute force
#   - CORS restrito às origens configuradas (nunca wildcard em prod)
#   - CloudWatch logs com KMS opcional e retenção configurável
#   - aws_lambda_permission com source_arn restrito a este API Gateway
# ==============================================================================

# --- KMS key para logs (quando fornecida) -------------------------------------
# Se kms_key_arn for vazio, o CloudWatch usa sua própria chave gerenciada pela AWS.
# Em prod, sempre forneça uma chave KMS dedicada para controle de acesso aos logs.
resource "aws_cloudwatch_log_group" "api_gw" {
  name              = "/aws/apigateway/${var.project_name}-auth-api"
  retention_in_days = var.log_retention_days
  kms_key_id        = var.kms_key_arn != "" ? var.kms_key_arn : null
}

# --- HTTP API -----------------------------------------------------------------
resource "aws_apigatewayv2_api" "auth" {
  name          = "${var.project_name}-auth-api"
  protocol_type = "HTTP"
  description   = "HTTP API Gateway para autenticação via CPF — dispara Lambda"

  # CORS explícito: restringe origens, métodos e headers aceitos.
  # Nunca use allow_origins = ["*"] em produção — restrinja ao(s) domínio(s) da aplicação.
  dynamic "cors_configuration" {
    for_each = length(var.cors_allow_origins) > 0 ? [1] : []
    content {
      allow_origins = var.cors_allow_origins
      allow_methods = ["POST", "OPTIONS"]
      allow_headers = var.cors_allow_headers
      max_age       = var.cors_max_age
    }
  }
}

# --- Stage padrão com auto-deploy e throttling --------------------------------
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.auth.id
  name        = "$default"
  auto_deploy = true

  # Throttling: limita burst e rate para proteger a Lambda e o banco de dados
  # contra DoS e tentativas de enumeração de CPF por força bruta.
  default_route_settings {
    throttling_burst_limit = var.throttling_burst_limit
    throttling_rate_limit  = var.throttling_rate_limit
  }

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
# source_arn com /*/*  limita a invocação somente a rotas deste API Gateway,
# impedindo que qualquer outro serviço invoque a Lambda usando esta permissão.
resource "aws_lambda_permission" "allow_api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.auth.execution_arn}/*/*"
}

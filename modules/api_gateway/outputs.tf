# ==============================================================================
# Outputs — Módulo API Gateway
# ==============================================================================

output "api_endpoint" {
  description = "URL base do API Gateway — ex: https://<id>.execute-api.<região>.amazonaws.com"
  value       = aws_apigatewayv2_api.auth.api_endpoint
}

output "api_id" {
  description = "ID do HTTP API Gateway"
  value       = aws_apigatewayv2_api.auth.id
}

output "execution_arn" {
  description = "ARN de execução do API Gateway — usado para permissões Lambda"
  value       = aws_apigatewayv2_api.auth.execution_arn
}

output "auth_url" {
  description = "URL completa do endpoint de autenticação (POST /auth)"
  value       = "${aws_apigatewayv2_api.auth.api_endpoint}/auth"
}

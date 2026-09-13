# ==============================================================================
# Outputs — Módulo Lambda
# ==============================================================================

output "function_arn" {
  description = "ARN da função Lambda"
  value       = aws_lambda_function.auth.arn
}

output "invoke_arn" {
  description = "ARN de invocação — usado pela integração do API Gateway"
  value       = aws_lambda_function.auth.invoke_arn
}

output "function_name" {
  description = "Nome da função Lambda"
  value       = aws_lambda_function.auth.function_name
}

output "qualified_arn" {
  description = "ARN qualificado da Lambda (inclui versão)"
  value       = aws_lambda_function.auth.qualified_arn
}

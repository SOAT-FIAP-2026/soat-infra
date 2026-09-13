# ==============================================================================
# Variáveis — Módulo API Gateway
# ==============================================================================

variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos"
  type        = string
}

variable "lambda_invoke_arn" {
  description = "ARN de invocação da Lambda integrada ao API Gateway"
  type        = string
}

variable "lambda_function_name" {
  description = "Nome da função Lambda — necessário para a permissão de invocação"
  type        = string
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs do API Gateway no CloudWatch"
  type        = number
  default     = 7
}

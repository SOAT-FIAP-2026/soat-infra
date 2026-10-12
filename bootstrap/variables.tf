# ==============================================================================
# Variáveis — Bootstrap Permanente
# ==============================================================================

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo dos recursos"
  type        = string
  default     = "techchallenge"
}

# --- Valores iniciais dos parâmetros SSM (usados apenas na primeira criação) --

variable "initial_jwt_secret" {
  description = "Chave HMAC-SHA256 inicial para assinatura do JWT. Mínimo 32 caracteres."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.initial_jwt_secret) >= 32
    error_message = "initial_jwt_secret precisa ter pelo menos 32 caracteres."
  }
}

variable "initial_jwt_issuer" {
  description = "Claim iss do JWT — deve ser idêntico ao Jwt__Issuer da API Principal"
  type        = string
  default     = "TechChallenge"
}

variable "initial_jwt_audience" {
  description = "Claim aud do JWT — deve ser idêntico ao Jwt__Audience da API Principal"
  type        = string
  default     = "techchallenge.com.br"
}

variable "initial_jwt_expires_in_seconds" {
  description = "Validade do token em segundos"
  type        = string
  default     = "3600"
}

variable "initial_db_username" {
  description = "Usuário master inicial do RDS PostgreSQL"
  type        = string
  default     = "postgres"
}

variable "initial_db_password" {
  description = "Senha master inicial do RDS PostgreSQL"
  type        = string
  sensitive   = true
}

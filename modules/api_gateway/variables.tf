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

# --- Throttling ---------------------------------------------------------------
# Limita requisições para proteger contra DoS e enumeração de CPF por força bruta
variable "throttling_burst_limit" {
  description = "Número máximo de requisições concorrentes (burst) permitidas"
  type        = number
  default     = 50
}

variable "throttling_rate_limit" {
  description = "Número máximo de requisições por segundo (steady-state)"
  type        = number
  default     = 10
}

# --- CORS ---------------------------------------------------------------------
variable "cors_allow_origins" {
  description = "Lista de origens permitidas no CORS. Use ['*'] apenas em dev controlado"
  type        = list(string)
  default     = []
}

variable "cors_allow_headers" {
  description = "Headers HTTP permitidos nas requisições CORS"
  type        = list(string)
  default     = ["Content-Type", "Authorization"]
}

variable "cors_max_age" {
  description = "Tempo em segundos que o browser pode cachear a resposta de preflight CORS"
  type        = number
  default     = 300
}

# --- KMS ----------------------------------------------------------------------
variable "kms_key_arn" {
  description = "ARN da chave KMS para criptografar os logs do CloudWatch. Deixar vazio usa a chave gerenciada pela AWS"
  type        = string
  default     = ""
}

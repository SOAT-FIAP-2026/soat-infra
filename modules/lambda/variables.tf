# ==============================================================================
# Variáveis — Módulo Lambda
# ==============================================================================

variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos"
  type        = string
}

variable "function_name" {
  description = "Nome da função Lambda"
  type        = string
}

variable "handler" {
  description = "Handler da função Lambda (Assembly::Namespace.Class::Method)"
  type        = string
}

variable "runtime" {
  description = "Runtime da Lambda (ex: dotnet8)"
  type        = string
  default     = "dotnet8"
}

variable "timeout" {
  description = "Timeout da Lambda em segundos"
  type        = number
  default     = 30
}

variable "memory_size" {
  description = "Memória alocada para a Lambda em MB"
  type        = number
  default     = 256
}

# --- Origem do pacote ---------------------------------------------------------
variable "use_s3" {
  description = "Se true, carrega o pacote do S3; se false, usa arquivo local"
  type        = bool
  default     = false
}

variable "s3_bucket" {
  description = "Bucket S3 com o ZIP da Lambda (usado quando use_s3 = true)"
  type        = string
  default     = ""
}

variable "s3_key" {
  description = "Chave do objeto S3 com o ZIP da Lambda (usado quando use_s3 = true)"
  type        = string
  default     = ""
}

variable "local_package_path" {
  description = "Caminho local para o ZIP da Lambda (usado quando use_s3 = false)"
  type        = string
  default     = ""
}

variable "source_code_hash" {
  description = "Hash do pacote para forçar atualização quando o código mudar"
  type        = string
  default     = ""
}

# --- Configuração de runtime --------------------------------------------------
variable "environment_variables" {
  description = "Variáveis de ambiente injetadas na Lambda"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs no CloudWatch"
  type        = number
  default     = 7
}

# ==============================================================================
# Variáveis do Root Module
# ==============================================================================

variable "default_region" {
  description = "Região AWS padrão"
  type        = string
  default     = "sa-east-1"
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo em todos os recursos AWS"
  type        = string
  default     = "fiap-soat-terraform"
}

variable "cidr_block" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs disponíveis na região (subnets usam as 2 primeiras)"
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1b", "sa-east-1c"]
}

variable "instance_types" {
  description = "Tipos de instância EC2 para os nodes do EKS"
  type        = list(string)
  default     = ["t3.small"]
}

variable "grafana_admin_password" {
  description = "Senha do admin do Grafana — definir como variável sensível no Terraform Cloud"
  type        = string
  default     = "admin"
  sensitive   = true
}

# --- Lambda + API Gateway -----------------------------------------------------
variable "lambda_s3_bucket" {
  description = "Bucket S3 que contém o ZIP publicado da Lambda de autenticação"
  type        = string
  default     = "fiap-soat-techchallenge-backend"
}

variable "lambda_s3_key" {
  description = "Chave S3 do ZIP da Lambda — atualizada pelo CI/CD após cada build"
  type        = string
  default     = "lambda/auth/lambda-auth.zip"
}

variable "db_connection_string" {
  description = "Connection string do PostgreSQL RDS para a Lambda"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Segredo para assinar os tokens JWT — deve ter no mínimo 32 caracteres"
  type        = string
  sensitive   = true
}

variable "jwt_expires_in_seconds" {
  description = "Tempo de expiração do JWT em segundos"
  type        = string
  default     = "3600"
}

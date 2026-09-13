# ==============================================================================
# Variáveis — Ambiente DEV
# ==============================================================================
# Em dev, usamos valores padrão seguros para testes locais com Floci.
# Credenciais não são reais — são aceitas pelo emulador local.
# ==============================================================================

variable "aws_region" {
  description = "Região da AWS (ignorada pelo Floci, mas necessária para o provider)"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto — usado como prefixo em todos os recursos"
  type        = string
  default     = "techchallenge"
}

variable "cidr_block" {
  description = "CIDR block da VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs (fictícias em dev — Floci aceita qualquer valor)"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "instance_types" {
  description = "Tipos de instância EC2 para os nodes do EKS (fictício em dev)"
  type        = list(string)
  default     = ["t3.micro"]
}

# --- Lambda + API Gateway -----------------------------------------------------
variable "lambda_package_path" {
  description = "Caminho local para o ZIP da Lambda publicado com 'dotnet lambda package'"
  type        = string
  # Após buildar: dotnet lambda package -o publish.zip
  # no diretório lambda-auth-function/src/Fiap.TechChallenge.LambdaAuth
  default = "../../../../lambda-auth-function/src/Fiap.TechChallenge.LambdaAuth/publish.zip"
}

variable "db_connection_string" {
  description = "Connection string do PostgreSQL para a Lambda (fictícia em dev)"
  type        = string
  default     = "Host=localhost;Port=5432;Database=techchallenge;Username=postgres;Password=postgres"
  sensitive   = true
}

variable "jwt_secret" {
  description = "Segredo para assinar os tokens JWT (fictício em dev)"
  type        = string
  default     = "dev-secret-key-change-in-production-min-32-chars"
  sensitive   = true
}

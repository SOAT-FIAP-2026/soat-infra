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

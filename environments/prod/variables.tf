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

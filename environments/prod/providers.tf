# ==============================================================================
# Provider — Ambiente PROD
# ==============================================================================
#
# ⚠️  ISOLAMENTO DE ESTADO:
#   O estado de produção é armazenado REMOTAMENTE em um bucket S3.
#   Isso garante:
#     1. Isolamento total do estado de dev (que é local).
#     2. Acesso compartilhado e seguro pela equipe e CI/CD.
#
#   - Dev:  estado LOCAL  → environments/dev/terraform.tfstate
#   - Prod: estado REMOTO → s3://bucket/k8s/terraform.tfstate
#
#   Cada ambiente tem seu próprio 'terraform init' e 'terraform apply',
#   executados DENTRO da sua respectiva pasta.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "fiap-soat-techchallenge-backend"
    key    = "k8s/terraform.tfstate"
    region = "sa-east-1"
  }
}

provider "aws" {
  region = var.default_region

  default_tags {
    tags = {
      Project     = "techchallenge"
      Environment = "prod"
      ManagedBy   = "terraform"
    }
  }
}

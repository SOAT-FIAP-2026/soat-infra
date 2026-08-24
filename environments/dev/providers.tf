# ==============================================================================
# Provider — Ambiente DEV (Floci / LocalStack)
# ==============================================================================
#
# O estado do Terraform para DEV é armazenado localmente (terraform.tfstate).
# Isso garante isolamento completo em relação ao ambiente de produção, que usa
# um backend remoto (S3 + DynamoDB). Cada ambiente opera em seu próprio
# diretório com seu próprio arquivo de estado — nunca compartilhados.
#
# ⚠️  ISOLAMENTO DE ESTADO:
#   - Dev:  estado LOCAL  → environments/dev/terraform.tfstate
#   - Prod: estado REMOTO → s3://bucket/k8s/terraform.tfstate
#   Cada 'terraform init' e 'terraform apply' é executado DENTRO da pasta
#   do respectivo ambiente, garantindo que um não interfira no outro.
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Dev usa backend local (padrão do Terraform).
  # O arquivo terraform.tfstate será criado nesta pasta.
  # Ele está listado no .gitignore e NÃO deve ser versionado.
}

provider "aws" {
  region                      = var.aws_region
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  # Todos os endpoints apontam para o Floci compartilhado (emulador local de AWS)
  # Suba o Floci via: docker compose up -d  (na raiz do workspace FIAP - TC/)
  endpoints {
    ec2 = "http://localhost:4566"
    eks = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

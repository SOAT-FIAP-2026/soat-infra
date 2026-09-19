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
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }

  backend "s3" {
    bucket         = "soat-fiap-backend-tfstate"
    key            = "k8s/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "soat-fiap-terraform-locks"
    encrypt        = true
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

# --- Autenticação dinâmica no EKS (compatível com Terraform Cloud) -----------
# Usa data source da AWS para gerar token de autenticação via SDK,
# sem depender do binário aws cli no runner remoto.
data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

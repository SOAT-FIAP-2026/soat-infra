# ==============================================================================
# Bootstrap Permanente — S3 State + DynamoDB Lock + SSM Parameters
# ==============================================================================
#
# ⚠️  EXECUTAR APENAS UMA VEZ — NUNCA DESTRUIR!
#
# Cria a infraestrutura de fundação compartilhada pela equipe:
#   1. Bucket S3 com versionamento para armazenar terraform.tfstate
#   2. Tabela DynamoDB para locking de concorrência
#   3. Parâmetros no SSM Parameter Store (segredos JWT + credenciais DB)
#
# O nome do bucket é determinístico: soat-fiap-tfstate-<ACCOUNT_ID>
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
      Component = "bootstrap"
    }
  }
}

# --- Account ID para nome determinístico do bucket ---------------------------
data "aws_caller_identity" "current" {}

locals {
  bucket_name = "soat-fiap-tfstate-${data.aws_caller_identity.current.account_id}"
}

# ==============================================================================
# S3 — Armazenamento do Terraform State
# ==============================================================================

resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ==============================================================================
# DynamoDB — Locking de Concorrência
# ==============================================================================

resource "aws_dynamodb_table" "locks" {
  name         = "soat-fiap-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

# ==============================================================================
# SSM Parameter Store — Segredos e Claims JWT
# ==============================================================================

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/techchallenge/prod/jwt_secret"
  type  = "SecureString"
  value = var.initial_jwt_secret

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_issuer" {
  name  = "/techchallenge/prod/jwt_issuer"
  type  = "String"
  value = var.initial_jwt_issuer

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_audience" {
  name  = "/techchallenge/prod/jwt_audience"
  type  = "String"
  value = var.initial_jwt_audience

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "jwt_expires_in_seconds" {
  name  = "/techchallenge/prod/jwt_expires_in_seconds"
  type  = "String"
  value = var.initial_jwt_expires_in_seconds

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/techchallenge/prod/db_username"
  type  = "String"
  value = var.initial_db_username

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/techchallenge/prod/db_password"
  type  = "SecureString"
  value = var.initial_db_password

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "db_connection_string" {
  name  = "/techchallenge/prod/db_connection_string"
  type  = "SecureString"
  value = "Host=placeholder;Port=5432;Database=techchallenge;Username=placeholder;Password=placeholder;"

  lifecycle {
    ignore_changes = [value]
  }
}


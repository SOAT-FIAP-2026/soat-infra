# ==============================================================================
# Main — Ambiente DEV
# ==============================================================================
# Configurações para desenvolvimento e testes locais (Floci / LocalStack).
# Emula VPC, IAM e EKS localmente sem custos AWS.
#
# Nota: O Floci emula as APIs do EKS mas não sobe um cluster real.
# O objetivo aqui é validar a configuração Terraform (plan/apply) sem
# precisar provisionar recursos reais na AWS.
# ==============================================================================

# --- Módulo: Networking -------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project_name       = var.project_name
  cidr_block         = var.cidr_block
  availability_zones = var.availability_zones
}

# --- Módulo: IAM --------------------------------------------------------------
# Em dev, policy attachments e OIDC/EBS CSI desabilitados — Floci não suporta
module "iam" {
  source = "../../modules/iam"

  project_name              = var.project_name
  create_policy_attachments = false
  create_ebs_csi_role       = false
}

# --- Módulo: EKS --------------------------------------------------------------
# Em dev, o terraform_user_arn usa um ARN fictício aceito pelo Floci.
module "eks" {
  source = "../../modules/eks"

  project_name          = var.project_name
  cluster_role_arn      = module.iam.cluster_role_arn
  node_group_role_arn   = module.iam.node_group_role_arn
  subnet_ids            = module.networking.public_subnet_ids
  security_group_id     = module.networking.main_security_group_id
  instance_types        = var.instance_types
  terraform_user_arn    = "arn:aws:iam::000000000000:user/terraform-user"
  create_node_group     = false
  create_access_entries = false
  create_ebs_csi_driver = false

  # Propaga dependências de policy para garantir a ordem correta
  cluster_policy_attachment_dep  = module.iam.cluster_policy_attachment
  node_cni_policy_attachment_dep = module.iam.node_cni_policy_attachment
  node_ecr_policy_attachment_dep = module.iam.node_ecr_policy_attachment
}

# --- Módulo: Lambda -----------------------------------------------------------
# Em dev, carrega o ZIP local compilado com 'dotnet lambda package'.
# Variáveis sensíveis usam valores fictícios adequados ao Floci.
module "lambda" {
  source = "../../modules/lambda"

  project_name  = var.project_name
  function_name = "${var.project_name}-lambda-auth"
  handler       = "Fiap.TechChallenge.LambdaAuth::Fiap.TechChallenge.LambdaAuth.Function::HandleAsync"
  runtime       = "dotnet8"

  # Pacote local — não usa S3 em dev
  use_s3             = false
  local_package_path = var.lambda_package_path

  environment_variables = {
    DB_CONNECTION_STRING   = var.db_connection_string
    JWT_SECRET             = var.jwt_secret
    JWT_ISSUER             = "fiap-tech-challenge"
    JWT_AUDIENCE           = "fiap-api"
    JWT_EXPIRES_IN_SECONDS = "3600"
  }
}

# --- Módulo: API Gateway ------------------------------------------------------
# HTTP API v2 com rota POST /auth integrada à Lambda acima.
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name         = var.project_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
}

# ⚠️  OBSERVABILIDADE EM DEV:
# O módulo de observabilidade NÃO é instanciado em dev.
# O Floci emula APIs da AWS mas não roda um cluster K8s real — Helm falharia.
# A observabilidade local continua usando o Docker Compose existente em
# fase1-tech-challenge/docker-compose.yml.


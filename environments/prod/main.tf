# ==============================================================================
# Root Module — Orquestra os módulos de infraestrutura Kubernetes
# ==============================================================================

# --- Data Sources -------------------------------------------------------------
data "aws_iam_user" "terraform_user" {
  user_name = "terraform-user"
}

# --- Módulo: Networking -------------------------------------------------------
module "networking" {
  source = "../../modules/networking"

  project_name       = var.project_name
  cidr_block         = var.cidr_block
  availability_zones = var.availability_zones
}

# --- Módulo: IAM --------------------------------------------------------------
module "iam" {
  source = "../../modules/iam"

  project_name        = var.project_name
  eks_oidc_issuer_url = module.eks.oidc_issuer_url
  create_ebs_csi_role = true
}

# --- Módulo: EKS --------------------------------------------------------------
module "eks" {
  source = "../../modules/eks"

  project_name        = var.project_name
  cluster_role_arn    = module.iam.cluster_role_arn
  node_group_role_arn = module.iam.node_group_role_arn
  subnet_ids          = module.networking.public_subnet_ids
  security_group_id   = module.networking.main_security_group_id
  instance_types      = var.instance_types
  terraform_user_arn  = data.aws_iam_user.terraform_user.arn

  # EBS CSI Driver — necessário para PVCs da stack de observabilidade
  create_ebs_csi_driver = true
  ebs_csi_role_arn      = module.iam.ebs_csi_role_arn

  # Propaga dependências de policy para garantir a ordem correta de create/destroy
  cluster_policy_attachment_dep  = module.iam.cluster_policy_attachment
  node_cni_policy_attachment_dep = module.iam.node_cni_policy_attachment
  node_ecr_policy_attachment_dep = module.iam.node_ecr_policy_attachment
}

# --- Módulo: Lambda -----------------------------------------------------------
# Pacote carregado do S3 — o CI/CD faz 'dotnet lambda package' e faz upload
# antes do 'terraform apply', garantindo que o objeto exista no bucket.
module "lambda" {
  source = "../../modules/lambda"

  project_name  = var.project_name
  function_name = "${var.project_name}-lambda-auth"
  handler       = "Fiap.TechChallenge.LambdaAuth::Fiap.TechChallenge.LambdaAuth.Function::HandleAsync"
  runtime       = "dotnet8"
  memory_size   = 512
  timeout       = 30

  # Pacote via S3 (obrigatório em prod)
  use_s3    = true
  s3_bucket = var.lambda_s3_bucket
  s3_key    = var.lambda_s3_key

  log_retention_days = 14

  environment_variables = {
    DB_CONNECTION_STRING   = var.db_connection_string
    JWT_SECRET             = var.jwt_secret
    JWT_ISSUER             = "fiap-tech-challenge"
    JWT_AUDIENCE           = "fiap-api"
    JWT_EXPIRES_IN_SECONDS = var.jwt_expires_in_seconds
  }
}

# --- Módulo: API Gateway ------------------------------------------------------
# HTTP API v2 com rota POST /auth integrada à Lambda acima.
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name         = var.project_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  log_retention_days   = 14
}

# --- Módulo: Observabilidade --------------------------------------------------
# Stack completa: Prometheus, Grafana, Alertmanager, Loki, Tempo, OTel Collector.
# Grafana fica acessível externamente via AWS Load Balancer.
#
# ⚠️  PRIMEIRO DEPLOY:
#   No primeiro 'terraform apply', o cluster EKS pode ainda não estar pronto
#   quando o Terraform tenta configurar os providers Helm/Kubernetes.
#   Se ocorrer erro, execute novamente: terraform apply
module "observability" {
  source = "../../modules/observability"

  project_name           = var.project_name
  grafana_admin_password = var.grafana_admin_password
  grafana_service_type   = "LoadBalancer"

  # Destino real dos alertas. Vazio mantem o receiver "null": os alertas continuam
  # visiveis no Alertmanager, apenas sem notificacao externa.
  alertmanager_slack_webhook_url = var.alertmanager_slack_webhook_url
  alertmanager_slack_channel     = var.alertmanager_slack_channel
  alertmanager_webhook_url       = var.alertmanager_webhook_url

  depends_on = [module.eks]
}

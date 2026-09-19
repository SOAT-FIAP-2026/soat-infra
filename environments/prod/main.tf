# ==============================================================================
# Root Module — Orquestra os módulos de infraestrutura Kubernetes
# ==============================================================================

# --- Data Sources -------------------------------------------------------------
data "aws_iam_user" "terraform_user" {
  user_name = "fiap-soat"
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

  # Capacidade do Node Group: 3 nós garantem slots suficientes de pods (max 11 pods/nó em t3.small)
  # para a stack de observabilidade (Prometheus, Loki, Tempo, OTel) e a aplicação .NET.
  desired_size = 3
  max_size     = 4
  min_size     = 2

  # EBS CSI Driver — necessário para PVCs da stack de observabilidade
  create_ebs_csi_driver = true
  ebs_csi_role_arn      = module.iam.ebs_csi_role_arn

  # Propaga dependências de policy para garantir a ordem correta de create/destroy
  cluster_policy_attachment_dep  = module.iam.cluster_policy_attachment
  node_cni_policy_attachment_dep = module.iam.node_cni_policy_attachment
  node_ecr_policy_attachment_dep = module.iam.node_ecr_policy_attachment
}

# --- SSM Parameter Store — Leitura de segredos para a Lambda ------------------
# Os parâmetros de token JWT são lidos aqui. A string de conexão com o RDS é
# resolvida dinamicamente pela própria Lambda em tempo de execução via SSM.

data "aws_ssm_parameter" "jwt_secret" {
  name            = "/techchallenge/prod/jwt_secret"
  with_decryption = true
}

data "aws_ssm_parameter" "jwt_issuer" {
  name = "/techchallenge/prod/jwt_issuer"
}

data "aws_ssm_parameter" "jwt_audience" {
  name = "/techchallenge/prod/jwt_audience"
}

# --- Lambda: Placeholder do Pacote no S3 --------------------------------------
# Garante que um ZIP válido exista no S3 para o primeiro apply caso o CI/CD
# ainda não tenha feito upload do pacote compilado.
resource "aws_s3_object" "lambda_package_placeholder" {
  bucket = var.lambda_s3_bucket
  key    = var.lambda_s3_key
  # ZIP contendo placeholder.txt para atender à validação da AWS Lambda (que rejeita zips vazios)
  content_base64 = "UEsDBAoAAAAAALGMM10ggSzcDAAAAAwAAAAPABwAcGxhY2Vob2xkZXIudHh0VVQJAAOO8q5qjvKuanV4CwABBOgDAAAE6AMAAHBsYWNlaG9sZGVyClBLAQIeAwoAAAAAALGMM10ggSzcDAAAAAwAAAAPABgAAAAAAAEAAAC0gQAAAABwbGFjZWhvbGRlci50eHRVVAUAA47yrmp1eAsAAQToAwAABOgDAABQSwUGAAAAAAEAAQBVAAAAVQAAAAAA"

  lifecycle {
    ignore_changes = [content_base64, etag]
  }
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

  # Rede VPC: conecta a Lambda na mesma VPC para alcançar o RDS PostgreSQL
  subnet_ids         = module.networking.public_subnet_ids
  security_group_ids = [module.networking.main_security_group_id]

  # Credenciais e claims JWT lidas diretamente do SSM Parameter Store.
  # A connection string do RDS é resolvida dinamicamente pela própria Lambda
  # no cold start a partir do parâmetro SSM indicado abaixo.
  environment_variables = {
    SSM_DB_CONNECTION_STRING_PARAM = "/techchallenge/prod/db_connection_string"
    JWT_SECRET                     = data.aws_ssm_parameter.jwt_secret.value
    JWT_ISSUER                     = data.aws_ssm_parameter.jwt_issuer.value
    JWT_AUDIENCE                   = data.aws_ssm_parameter.jwt_audience.value
    JWT_EXPIRES_IN_SECONDS         = var.jwt_expires_in_seconds
  }

  depends_on = [aws_s3_object.lambda_package_placeholder]
}

# --- Módulo: API Gateway ------------------------------------------------------
# HTTP API v2 com rota POST /auth integrada à Lambda acima.
# Em prod: throttling conservador, CORS restrito ao domínio da aplicação,
# e logs criptografados com KMS.
module "api_gateway" {
  source = "../../modules/api_gateway"

  project_name         = var.project_name
  lambda_invoke_arn    = module.lambda.invoke_arn
  lambda_function_name = module.lambda.function_name
  log_retention_days   = 14

  # Throttling: 50 req/s em steady-state, burst de até 100.
  # Protege contra DoS e enumeração de CPF por força bruta.
  throttling_burst_limit = 100
  throttling_rate_limit  = 50

  # CORS: restringe ao(s) domínio(s) da aplicação em produção.
  cors_allow_origins = var.cors_allow_origins

  # KMS: criptografa logs do CloudWatch com chave gerenciada pelo projeto.
  kms_key_arn = var.api_gateway_kms_key_arn
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
  grafana_service_type   = "NodePort"

  # Destino real dos alertas. Vazio mantem o receiver "null": os alertas continuam
  # visiveis no Alertmanager, apenas sem notificacao externa.
  alertmanager_slack_webhook_url = var.alertmanager_slack_webhook_url
  alertmanager_slack_channel     = var.alertmanager_slack_channel
  alertmanager_webhook_url       = var.alertmanager_webhook_url

  depends_on = [module.eks]
}

# --- Módulo: Load Balancer (ALB) ---------------------------------------------
# Application Load Balancer gerenciado 100% pelo Terraform:
#   - Porta 80   → API .NET (NodePort 30080)
#   - Porta 3000 → Grafana (NodePort 30300)
# Garante URLs públicas no 'outputs' e destroy limpo sem ENIs presas na VPC.
module "load_balancer" {
  source = "../../modules/load-balancer"

  project_name           = var.project_name
  vpc_id                 = module.networking.vpc_id
  subnet_ids             = module.networking.public_subnet_ids
  autoscaling_group_name = module.eks.node_group_autoscaling_group_name
  node_security_group_id = module.eks.cluster_security_group_id

  api_node_port     = 30080
  grafana_node_port = 30300

  depends_on = [module.eks]
}

# --- SSM: Publicação do DNS do ALB --------------------------------------------
resource "aws_ssm_parameter" "alb_dns" {
  name      = "/techchallenge/prod/alb_dns"
  type      = "String"
  value     = module.load_balancer.dns_name
  overwrite = true
}

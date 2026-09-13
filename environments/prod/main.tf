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

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
# Em dev, policy attachments desabilitados — Floci não possui as managed policies da AWS
module "iam" {
  source = "../../modules/iam"

  project_name              = var.project_name
  create_policy_attachments = false
}

# --- Módulo: EKS --------------------------------------------------------------
# Em dev, o terraform_user_arn usa um ARN fictício aceito pelo Floci.
module "eks" {
  source = "../../modules/eks"

  project_name        = var.project_name
  cluster_role_arn    = module.iam.cluster_role_arn
  node_group_role_arn = module.iam.node_group_role_arn
  subnet_ids          = module.networking.public_subnet_ids
  security_group_id   = module.networking.main_security_group_id
  instance_types      = var.instance_types
  terraform_user_arn  = "arn:aws:iam::000000000000:user/terraform-user"
  create_node_group   = false
  create_access_entries = false

  # Propaga dependências de policy para garantir a ordem correta
  cluster_policy_attachment_dep  = module.iam.cluster_policy_attachment
  node_cni_policy_attachment_dep = module.iam.node_cni_policy_attachment
  node_ecr_policy_attachment_dep = module.iam.node_ecr_policy_attachment
}

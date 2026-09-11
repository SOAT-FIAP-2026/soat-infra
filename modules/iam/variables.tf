variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos IAM"
  type        = string
}

variable "create_policy_attachments" {
  description = "Define se os policy attachments (AWS managed policies) devem ser criados. False para ambientes locais (Floci/LocalStack) que não possuem as managed policies."
  type        = bool
  default     = true
}

variable "eks_oidc_issuer_url" {
  description = "URL do OIDC Issuer do cluster EKS — necessário para IRSA (IAM Roles for Service Accounts)"
  type        = string
  default     = ""
}

variable "create_ebs_csi_role" {
  description = "Define se a IAM Role para o EBS CSI Driver (IRSA) deve ser criada. False para ambientes locais."
  type        = bool
  default     = true
}


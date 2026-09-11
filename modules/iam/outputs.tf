output "cluster_role_arn" {
  description = "ARN da IAM Role do EKS Control Plane"
  value       = aws_iam_role.cluster.arn
}

output "cluster_role_name" {
  description = "Nome da IAM Role do EKS Control Plane"
  value       = aws_iam_role.cluster.name
}

output "node_group_role_arn" {
  description = "ARN da IAM Role do Node Group"
  value       = aws_iam_role.node_group.arn
}

output "cluster_policy_attachment" {
  description = "Referência ao policy attachment do cluster (para depends_on). Null quando create_policy_attachments = false."
  value       = var.create_policy_attachments ? aws_iam_role_policy_attachment.cluster_AmazonEKSClusterPolicy[0] : null
}

output "node_cni_policy_attachment" {
  description = "Referência ao CNI policy attachment (para depends_on). Null quando create_policy_attachments = false."
  value       = var.create_policy_attachments ? aws_iam_role_policy_attachment.node_group_AmazonEKS_CNI_Policy[0] : null
}

output "node_ecr_policy_attachment" {
  description = "Referência ao ECR policy attachment (para depends_on). Null quando create_policy_attachments = false."
  value       = var.create_policy_attachments ? aws_iam_role_policy_attachment.node_group_AmazonEC2ContainerRegistryReadOnly[0] : null
}

# --- Outputs IRSA / EBS CSI --------------------------------------------------
output "ebs_csi_role_arn" {
  description = "ARN da IAM Role do EBS CSI Driver (IRSA). Vazio quando create_ebs_csi_role = false."
  value       = var.create_ebs_csi_role ? aws_iam_role.ebs_csi[0].arn : ""
}

output "oidc_provider_arn" {
  description = "ARN do OIDC Provider para IRSA. Vazio quando create_ebs_csi_role = false."
  value       = var.create_ebs_csi_role ? aws_iam_openid_connect_provider.eks[0].arn : ""
}


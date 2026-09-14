output "cluster_name" {
  description = "Nome do cluster EKS — usado pelo kubectl e CI/CD"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "Endpoint do API server do EKS"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_ca_certificate" {
  description = "Certificado CA do cluster (base64) — necessário para autenticação kubectl"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "oidc_issuer_url" {
  description = "URL do OIDC Issuer do cluster EKS — necessário para IRSA"
  value       = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

output "node_group_autoscaling_group_name" {
  description = "Nome do Auto Scaling Group associado ao Node Group do EKS"
  value       = var.create_node_group && length(aws_eks_node_group.main) > 0 ? aws_eks_node_group.main[0].resources[0].autoscaling_groups[0].name : ""
}

output "cluster_security_group_id" {
  description = "ID do Security Group gerenciado pelo EKS anexado ao cluster e aos nós"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}


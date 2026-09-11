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


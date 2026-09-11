# ==============================================================================
# Outputs do Root Module — agrega outputs de todos os módulos
# ==============================================================================

# ── Networking ────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID da VPC criada"
  value       = module.networking.vpc_id
}

output "vpc_cidr_block" {
  description = "CIDR block da VPC"
  value       = module.networking.vpc_cidr_block
}

output "subnet_ids" {
  description = "IDs das subnets públicas"
  value       = module.networking.public_subnet_ids
}

output "subnet_cidr_blocks" {
  description = "CIDR blocks das subnets públicas"
  value       = module.networking.public_subnet_cidr_blocks
}

output "security_group_id" {
  description = "ID do Security Group principal"
  value       = module.networking.main_security_group_id
}

# ── EKS ───────────────────────────────────────────────────────────────────────
output "eks_cluster_name" {
  description = "Nome do cluster EKS — usado pelo kubectl e CI/CD"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do API server do EKS"
  value       = module.eks.cluster_endpoint
}

output "eks_cluster_ca_certificate" {
  description = "Certificado CA do cluster (base64)"
  value       = module.eks.cluster_ca_certificate
  sensitive   = true
}

# ── Observabilidade ──────────────────────────────────────────────────────────
output "grafana_access" {
  description = "Comando para obter o endereço externo do Grafana"
  value       = "kubectl get svc -n monitoring kube-prometheus-stack-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}

output "otel_collector_endpoint" {
  description = "Endpoint OTLP interno — configurar no ConfigMap da aplicação"
  value       = module.observability.otel_collector_endpoint
}


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

# ── Lambda + API Gateway ──────────────────────────────────────────────────────
output "lambda_function_name" {
  description = "Nome da função Lambda de autenticação"
  value       = module.lambda.function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda de autenticação"
  value       = module.lambda.function_arn
}

output "api_gateway_endpoint" {
  description = "URL base do API Gateway"
  value       = module.api_gateway.api_endpoint
}

output "auth_url" {
  description = "Endpoint de autenticação — POST /auth"
  value       = module.api_gateway.auth_url
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
  description = "URL pública de acesso ao Grafana via ALB"
  value       = module.load_balancer.grafana_url
}

output "otel_collector_endpoint" {
  description = "Endpoint OTLP interno — configurar no ConfigMap da aplicação"
  value       = module.observability.otel_collector_endpoint
}

# ── Load Balancer (URLs Públicas) ─────────────────────────────────────────────
output "alb_dns_name" {
  description = "DNS público do Application Load Balancer"
  value       = module.load_balancer.dns_name
}

output "api_url" {
  description = "URL pública base da API .NET"
  value       = module.load_balancer.api_url
}

output "api_swagger_url" {
  description = "URL pública da documentação Swagger da API"
  value       = module.load_balancer.api_swagger_url
}

output "grafana_url" {
  description = "URL pública do Grafana (porta 3000)"
  value       = module.load_balancer.grafana_url
}


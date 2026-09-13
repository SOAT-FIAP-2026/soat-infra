# ==============================================================================
# Outputs — Ambiente DEV
# ==============================================================================

# ── Networking ────────────────────────────────────────────────────────────────
output "vpc_id" {
  description = "ID da VPC criada no Floci"
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
  description = "Nome do cluster EKS emulado"
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "Endpoint do API server do EKS emulado"
  value       = module.eks.cluster_endpoint
}

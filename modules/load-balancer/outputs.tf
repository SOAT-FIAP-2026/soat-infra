# ==============================================================================
# Outputs — Módulo de Load Balancer (ALB)
# ==============================================================================

output "dns_name" {
  description = "DNS name público do Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN do Application Load Balancer"
  value       = aws_lb.main.arn
}

output "alb_security_group_id" {
  description = "ID do Security Group do ALB"
  value       = aws_security_group.alb.id
}

output "api_target_group_arn" {
  description = "ARN do Target Group da API"
  value       = aws_lb_target_group.api.arn
}

output "grafana_target_group_arn" {
  description = "ARN do Target Group do Grafana"
  value       = aws_lb_target_group.grafana.arn
}

output "api_url" {
  description = "URL pública base da API"
  value       = "http://${aws_lb.main.dns_name}"
}

output "api_swagger_url" {
  description = "URL pública do Swagger da API"
  value       = "http://${aws_lb.main.dns_name}/swagger"
}

output "grafana_url" {
  description = "URL pública do Grafana"
  value       = "http://${aws_lb.main.dns_name}:3000"
}

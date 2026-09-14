# ==============================================================================
# Variáveis — Módulo de Load Balancer (ALB)
# ==============================================================================

variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC onde o Load Balancer e Target Groups serão criados"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets públicas onde o ALB será provisionado"
  type        = list(string)
}

variable "autoscaling_group_name" {
  description = "Nome do Auto Scaling Group dos nós do EKS para associar aos Target Groups"
  type        = string
  default     = ""
}

variable "api_node_port" {
  description = "Porta NodePort do Service da API no Kubernetes"
  type        = number
  default     = 30080
}

variable "grafana_node_port" {
  description = "Porta NodePort do Service do Grafana no Kubernetes"
  type        = number
  default     = 30300
}

variable "api_health_check_path" {
  description = "Path de health check para o Target Group da API"
  type        = string
  default     = "/health/live"
}

variable "grafana_health_check_path" {
  description = "Path de health check para o Target Group do Grafana"
  type        = string
  default     = "/api/health"
}

variable "node_security_group_id" {
  description = "ID do Security Group dos nós do EKS para liberar tráfego do ALB"
  type        = string
  default     = ""
}

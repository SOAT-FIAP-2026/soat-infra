# ==============================================================================
# Variáveis — Módulo de Observabilidade
# ==============================================================================

variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos"
  type        = string
}

variable "namespace" {
  description = "Namespace Kubernetes onde a stack de observabilidade será instalada"
  type        = string
  default     = "monitoring"
}

variable "grafana_admin_password" {
  description = "Senha do admin do Grafana — definir como variável sensível no Terraform Cloud"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "grafana_service_type" {
  description = "Tipo do Service do Grafana. LoadBalancer para acesso externo na AWS, ClusterIP para acesso interno."
  type        = string
  default     = "LoadBalancer"
}

variable "enable_loki" {
  description = "Define se o Loki (armazenamento de logs) deve ser instalado"
  type        = bool
  default     = true
}

variable "enable_tempo" {
  description = "Define se o Tempo (armazenamento de traces) deve ser instalado"
  type        = bool
  default     = true
}

variable "enable_blackbox" {
  description = "Define se o Blackbox Exporter (sondas HTTP de uptime) deve ser instalado"
  type        = bool
  default     = true
}

variable "enable_otel_collector" {
  description = "Define se o OpenTelemetry Collector deve ser instalado"
  type        = bool
  default     = true
}

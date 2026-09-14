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
  description = "Tipo do Service do Grafana. NodePort para ALB gerenciado pelo Terraform, LoadBalancer para Classic ELB, ClusterIP para acesso interno."
  type        = string
  default     = "NodePort"
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

variable "alertmanager_slack_webhook_url" {
  description = "Webhook do Slack que recebe os alertas do Alertmanager. Vazio mantém os alertas apenas na interface do Alertmanager."
  type        = string
  default     = ""
  sensitive   = true
}

variable "alertmanager_slack_channel" {
  description = "Canal do Slack usado quando alertmanager_slack_webhook_url está preenchido."
  type        = string
  default     = "#techchallenge-alertas"
}

variable "alertmanager_webhook_url" {
  description = "Webhook HTTP genérico que recebe os alertas (alternativa ao Slack). Vazio desativa o receiver."
  type        = string
  default     = ""
}

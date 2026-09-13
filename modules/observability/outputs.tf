# ==============================================================================
# Outputs — Módulo de Observabilidade
# ==============================================================================

output "namespace" {
  description = "Namespace onde a stack de observabilidade foi instalada"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_service_name" {
  description = "Nome do Service do Grafana — use kubectl get svc -n monitoring para obter o EXTERNAL-IP"
  value       = "kube-prometheus-stack-grafana"
}

output "otel_collector_endpoint" {
  description = "Endpoint OTLP interno (HTTP) para configurar na aplicação"
  value       = var.enable_otel_collector ? "http://opentelemetry-collector.${var.namespace}.svc.cluster.local:4318" : ""
}

output "prometheus_endpoint" {
  description = "Endpoint interno do Prometheus"
  value       = "http://kube-prometheus-stack-prometheus.${var.namespace}.svc.cluster.local:9090"
}

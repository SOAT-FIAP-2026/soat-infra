# ==============================================================================
# Módulo: observability
# Responsável por: Stack de observabilidade no Kubernetes (namespace monitoring)
# Componentes: kube-prometheus-stack, Blackbox Exporter, Loki, Tempo, OTel Collector
# ==============================================================================

# --- Roteamento de alertas do Alertmanager ------------------------------------
# Sem webhook configurado a stack sobe com o receiver "null": os alertas continuam
# sendo avaliados e visíveis na interface do Alertmanager, apenas sem envio externo.
# Com Slack ou webhook genérico preenchido, o alerta é roteado para o destino real,
# com critical e warning em grupos separados.
locals {
  alertmanager_receivers = concat(
    [{ name = "null" }],
    var.alertmanager_slack_webhook_url != "" ? [{
      name = "equipe"
      slack_configs = [{
        api_url       = var.alertmanager_slack_webhook_url
        channel       = var.alertmanager_slack_channel
        send_resolved = true
        title         = "{{ .CommonLabels.severity | toUpper }} — {{ .CommonAnnotations.summary }}"
        text          = <<-EOT
          {{ range .Alerts }}{{ .Annotations.description }}
          {{ end }}
        EOT
      }]
    }] : [],
    var.alertmanager_slack_webhook_url == "" && var.alertmanager_webhook_url != "" ? [{
      name = "equipe"
      webhook_configs = [{
        url           = var.alertmanager_webhook_url
        send_resolved = true
      }]
    }] : []
  )

  alertmanager_tem_destino = var.alertmanager_slack_webhook_url != "" || var.alertmanager_webhook_url != ""
  alertmanager_receiver    = local.alertmanager_tem_destino ? "equipe" : "null"

  alertmanager_config = {
    global = {
      resolve_timeout = "5m"
    }
    route = {
      group_by        = ["alertname", "severity"]
      group_wait      = "30s"
      group_interval  = "5m"
      repeat_interval = "4h"
      receiver        = local.alertmanager_receiver
      routes = [
        {
          matchers        = ["severity = critical"]
          receiver        = local.alertmanager_receiver
          group_wait      = "10s"
          repeat_interval = "1h"
        },
        {
          matchers        = ["severity = warning"]
          receiver        = local.alertmanager_receiver
          repeat_interval = "12h"
        }
      ]
    }
    receivers = local.alertmanager_receivers
  }
}

# --- Namespace ----------------------------------------------------------------
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.namespace

    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
      Project                        = var.project_name
    }
  }
}

# --- StorageClass gp3 (EBS CSI Driver) ----------------------------------------
# Define gp3 como StorageClass padrão para provisionamento dinâmico de volumes EBS.
# Necessário para os PVCs do Prometheus, Loki e Tempo.
resource "kubernetes_storage_class_v1" "gp3" {
  metadata {
    name = "gp3"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner    = "ebs.csi.aws.com"
  volume_binding_mode    = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type = "gp3"
  }
}

# --- kube-prometheus-stack ----------------------------------------------------
# Instala: Prometheus Operator, Alertmanager, Grafana, Node Exporter,
# Kube State Metrics e os CRDs (ServiceMonitor, PrometheusRule, Probe).
resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "62.7.0"

  cleanup_on_fail = true

  values = [
    file("${path.module}/values/prometheus-values.yaml"),
    yamlencode({
      grafana = {
        adminPassword = var.grafana_admin_password
        service = {
          type = var.grafana_service_type
        }
      }
      alertmanager = {
        config = local.alertmanager_config
      }
    })
  ]

  timeout = 600

  depends_on = [
    kubernetes_namespace.monitoring,
    kubernetes_storage_class_v1.gp3,
  ]
}

# --- Blackbox Exporter --------------------------------------------------------
# Necessário para o CRD Probe — sonda HTTP do endpoint /health/ready
resource "helm_release" "blackbox_exporter" {
  count      = var.enable_blackbox ? 1 : 0
  name       = "blackbox"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "prometheus-blackbox-exporter"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "9.0.1"

  cleanup_on_fail = true

  values = [
    yamlencode({
      resources = {
        requests = {
          cpu    = "10m"
          memory = "16Mi"
        }
        limits = {
          memory = "32Mi"
        }
      }
    })
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

# --- Loki (logs) --------------------------------------------------------------
# Armazenamento de logs estruturados — modo single-binary para nós pequenos
resource "helm_release" "loki" {
  count      = var.enable_loki ? 1 : 0
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "6.10.0"

  cleanup_on_fail = true

  values = [
    file("${path.module}/values/loki-values.yaml")
  ]

  timeout    = 600
  depends_on = [helm_release.kube_prometheus_stack]
}

# --- Tempo (traces) -----------------------------------------------------------
# Armazenamento de distributed traces — modo single-binary
resource "helm_release" "tempo" {
  count      = var.enable_tempo ? 1 : 0
  name       = "tempo"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "tempo"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "1.10.3"

  cleanup_on_fail = true

  values = [
    file("${path.module}/values/tempo-values.yaml")
  ]

  timeout    = 600
  depends_on = [helm_release.kube_prometheus_stack]
}

# --- OpenTelemetry Collector --------------------------------------------------
# Coletor centralizado OTLP: recebe traces/logs/métricas da aplicação .NET
# e encaminha para Tempo (traces) e Loki (logs)
resource "helm_release" "opentelemetry_collector" {
  count      = var.enable_otel_collector ? 1 : 0
  name       = "opentelemetry-collector"
  repository = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart      = "opentelemetry-collector"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name
  version    = "0.97.1"

  cleanup_on_fail = true

  values = [
    file("${path.module}/values/otel-values.yaml")
  ]

  timeout    = 300
  depends_on = [helm_release.loki, helm_release.tempo]
}

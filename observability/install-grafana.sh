#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Instalação avulsa da stack de observabilidade (Kind/Minikube sem Terraform)
# ==============================================================================
# Instala os mesmos componentes do módulo Terraform modules/observability, com os
# mesmos nomes de release, para que o dashboard da aplicação funcione igual nos
# dois caminhos. Em cluster gerenciado por este repositório, prefira:
#   terraform -chdir=environments/prod apply
# ==============================================================================

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULE_VALUES="$SCRIPT_DIR/../modules/observability/values"

echo "Instalando kube-prometheus-stack no namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/kube-prometheus-values.yaml" \
  --wait

helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter \
  --namespace "$NAMESPACE" \
  --version 9.0.1 \
  --wait

echo "Instalando Loki (logs)..."
helm upgrade --install loki grafana/loki \
  --namespace "$NAMESPACE" \
  --version 6.10.0 \
  --values "$MODULE_VALUES/loki-values.yaml" \
  --wait

echo "Instalando Tempo (traces)..."
helm upgrade --install tempo grafana/tempo \
  --namespace "$NAMESPACE" \
  --version 1.10.3 \
  --values "$MODULE_VALUES/tempo-values.yaml" \
  --wait

echo "Instalando OpenTelemetry Collector..."
helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector \
  --namespace "$NAMESPACE" \
  --version 0.97.1 \
  --values "$MODULE_VALUES/otel-values.yaml" \
  --wait

echo "Stack Grafana/Prometheus/Loki/Tempo instalado."
echo "Depois, no repositório fase1-tech-challenge, execute:"
echo "  ./k8s/observability/install.sh"
echo ""
echo "Endpoint OTLP para a aplicação (já configurado nos overlays):"
echo "  http://opentelemetry-collector.$NAMESPACE.svc.cluster.local:4318"
echo ""
echo "Grafana: kubectl port-forward svc/monitoring-grafana 3000:80 -n $NAMESPACE"
echo "Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n $NAMESPACE"

#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="monitoring"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Instalando kube-prometheus-stack no namespace $NAMESPACE..."
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace "$NAMESPACE" \
  --values "$SCRIPT_DIR/kube-prometheus-values.yaml" \
  --wait

helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter \
  --namespace "$NAMESPACE" \
  --wait

echo "Stack Grafana/Prometheus instalado."
echo "Depois, no repositório fase1-tech-challenge, execute:"
echo "  ./k8s/observability/install.sh"
echo ""
echo "Grafana: kubectl port-forward svc/monitoring-grafana 3000:80 -n $NAMESPACE"
echo "Prometheus: kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n $NAMESPACE"

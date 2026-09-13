#!/usr/bin/env bash
set -euo pipefail

: "${DD_API_KEY:?Defina DD_API_KEY antes de executar o script}"
DD_SITE="${DD_SITE:-datadoghq.com}"
DD_CLUSTER_NAME="${DD_CLUSTER_NAME:-techchallenge-eks}"
NAMESPACE="datadog"

echo "📡 Instalando Datadog Agent no cluster ${DD_CLUSTER_NAME}..."

kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic datadog-api-key \
  --namespace "$NAMESPACE" \
  --from-literal=api-key="$DD_API_KEY" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add datadog https://helm.datadoghq.com
helm repo update

helm upgrade --install datadog-agent datadog/datadog \
  --namespace "$NAMESPACE" \
  --values "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/datadog-values.yaml" \
  --set "datadog.site=${DD_SITE}" \
  --set "datadog.clusterName=${DD_CLUSTER_NAME}" \
  --wait

echo "✅ Datadog Agent instalado."
echo "   Endpoint OTLP HTTP para a API: http://datadog-agent.${NAMESPACE}.svc.cluster.local:4318"

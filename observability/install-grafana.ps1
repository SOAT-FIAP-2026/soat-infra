$ErrorActionPreference = "Stop"

# ==============================================================================
# Instalação avulsa da stack de observabilidade (Kind/Minikube sem Terraform)
# ==============================================================================
# Equivalente Windows de install-grafana.sh. Instala os mesmos componentes do
# módulo Terraform modules/observability, com os mesmos nomes de release, para
# que o dashboard da aplicação funcione igual nos dois caminhos.
# ==============================================================================

$namespace = "monitoring"
$scriptDir = Split-Path -Parent $PSCommandPath
$valuesFile = Join-Path $scriptDir "kube-prometheus-values.yaml"
$moduleValues = Join-Path $scriptDir "..\modules\observability\values"

kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm repo add grafana https://grafana.github.io/helm-charts --force-update
helm repo add open-telemetry https://open-telemetry.github.io/opentelemetry-helm-charts --force-update
helm repo update

helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
    --namespace $namespace `
    --values $valuesFile `
    --wait

helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter `
    --namespace $namespace `
    --version 9.0.1 `
    --wait

Write-Host "Instalando Loki (logs)..."
helm upgrade --install loki grafana/loki `
    --namespace $namespace `
    --version 6.10.0 `
    --values (Join-Path $moduleValues "loki-values.yaml") `
    --wait

Write-Host "Instalando Tempo (traces)..."
helm upgrade --install tempo grafana/tempo `
    --namespace $namespace `
    --version 1.10.3 `
    --values (Join-Path $moduleValues "tempo-values.yaml") `
    --wait

Write-Host "Instalando OpenTelemetry Collector..."
helm upgrade --install opentelemetry-collector open-telemetry/opentelemetry-collector `
    --namespace $namespace `
    --version 0.97.1 `
    --values (Join-Path $moduleValues "otel-values.yaml") `
    --wait

Write-Host "Stack Grafana/Prometheus/Loki/Tempo instalado. Prossiga com k8s/observability/install.ps1 na aplicação."
Write-Host "Endpoint OTLP: http://opentelemetry-collector.$namespace.svc.cluster.local:4318"

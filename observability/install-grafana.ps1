$ErrorActionPreference = "Stop"

$namespace = "monitoring"
$scriptDir = Split-Path -Parent $PSCommandPath
$valuesFile = Join-Path $scriptDir "kube-prometheus-values.yaml"

kubectl create namespace $namespace --dry-run=client -o yaml | kubectl apply -f -
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack `
    --namespace $namespace `
    --values $valuesFile `
    --wait
helm upgrade --install blackbox prometheus-community/prometheus-blackbox-exporter `
    --namespace $namespace `
    --wait

Write-Host "Stack Grafana/Prometheus instalado. Prossiga com k8s/observability/install.ps1 na aplicação."

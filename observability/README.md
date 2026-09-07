# Observabilidade local com Grafana

Estado em 07/09/2026: renderização Helm validada (chart 90.0.0), mas instalação em
cluster e painéis ao vivo não foram testados. Veja as [pendências do repositório](../docs/validation.md).

O caminho padrão para desenvolvimento e demonstração é Prometheus + Grafana +
Alertmanager, executados localmente no Minikube ou Kind. Esta opção não exige conta
AWS nem credenciais do Datadog.

## Instalação local

Pré-requisitos: Docker, Minikube ou Kind, kubectl e Helm.

    ./observability/install-grafana.sh

Depois, no repositório da aplicação:

    ./k8s/observability/install.sh

Interfaces:

    kubectl port-forward svc/monitoring-grafana 3000:80 -n monitoring
    kubectl port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090 -n monitoring

O Grafana local usa admin/admin. A configuração está em
observability/kube-prometheus-values.yaml. Altere a senha antes de usar um
cluster compartilhado.

O stack coleta:

- latência p95 e taxa de requisições da API;
- volume diário de ordens;
- tempo médio de Diagnóstico, Execução e Finalização;
- erros de integrações e falhas no processamento;
- CPU e memória dos containers via kubelet/cAdvisor, com estado e requests via kube-state-metrics;
- métricas da API por ServiceMonitor e disponibilidade das réplicas.

O script também instala o prometheus-blackbox-exporter. Depois de aplicar
k8s/observability/probe.yaml, o Prometheus consulta /health/ready e alimenta o alerta
de uptime. Logs JSON podem ser consultados com kubectl logs; o stack Kubernetes não
os armazena no Grafana. node-exporter fornece métricas do nó e não substitui cAdvisor
para os containers. Para centralizar logs e traces no cluster, configure um
OpenTelemetry Collector/Loki/Tempo e defina OTEL_EXPORTER_OTLP_ENDPOINT na aplicação.

O dashboard é provisionado pela aplicação em
observability/grafana/dashboards/techchallenge-observability.json.

## Datadog opcional para AWS

O Datadog permanece versionado como alternativa para um eventual ambiente AWS/EKS.
Ele somente deve ser instalado quando houver cluster, conta Datadog e DD_API_KEY.

O script install-datadog.sh passa na validação de sintaxe. Execute-o somente quando
houver cluster EKS e a API key disponível.

Este diretório instala e configura o Datadog Agent no EKS. O Agent coleta logs JSON dos containers, métricas de CPU/memória do Kubernetes, estado dos deployments e recebe traces/métricas OTLP enviados pela API.

## Pré-requisitos

- kubectl apontando para o EKS.
- Helm 3.
- Uma API key do Datadog.
- O namespace techchallenge e o deployment api publicados.

## Instalação

    export DD_API_KEY="sua-chave-do-datadog"
    export DD_SITE="datadoghq.com"       # ou datadoghq.eu
    export DD_CLUSTER_NAME="techchallenge-eks"
    ./install-datadog.sh

O script cria somente o Secret local com a API key e instala o chart oficial do Datadog. A chave não deve ser commitada.

A API envia OTLP HTTP para:

    http://datadog-agent.datadog.svc.cluster.local:4318

Esse endpoint é configurado no overlay AWS do repositório da API.

## Dashboard e alertas

- datadog-dashboard.json: volume diário de ordens, duração média das etapas Diagnóstico/Execução/Finalização, latência, falhas de ordens, erros de integração e CPU/memória dos pods.
- datadog-monitors.json: alertas para falha de processamento, erro de integração, latência acima de 1 segundo e ausência de réplicas disponíveis.

Os JSONs são modelos versionados. Eles podem ser importados pela UI do Datadog ou aplicados pela API/Datadog Terraform Provider depois de configurar os canais de notificação da equipe.

## Operação

    kubectl get pods -n datadog
    kubectl logs -n datadog -l app.kubernetes.io/name=datadog
    kubectl get deployment api -n techchallenge
    kubectl describe hpa api-hpa -n techchallenge

Para correlacionar um alerta com uma requisição, copie o correlation_id do log JSON e pesquise pelo mesmo valor no Datadog.

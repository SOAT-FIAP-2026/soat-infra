# Observabilidade com Prometheus e Grafana

Estado em 09/09/2026: validação concluída em Kind com chart 90.0.0. Prometheus,
Grafana, Alertmanager, kube-state-metrics, node-exporter e Blackbox Exporter ficaram
saudáveis; a API foi coletada por ServiceMonitor e o Probe de health retornou sucesso.
Veja o relatório integrado de evidências em
`fase1-tech-challenge/docs/validation-report.md`.

Prometheus + Grafana + Alertmanager é a solução oficial para desenvolvimento,
demonstração e operação desta entrega. Ela executa localmente no Minikube ou Kind e
não exige conta AWS nem credenciais do Datadog/New Relic. A justificativa da escolha
está em
[ADR-003](https://github.com/SOAT-FIAP-2026/fase1-tech-challenge/blob/main/docs/adrs/ADR-003-observability-stack.md).

## Dois caminhos de instalação

| Caminho | Quando usar | O que instala |
|---|---|---|
| `modules/observability` (Terraform) | EKS e qualquer cluster gerenciado por este repositório — **caminho oficial** | kube-prometheus-stack, Blackbox Exporter, Loki, Tempo, OpenTelemetry Collector, StorageClass `gp3` e roteamento do Alertmanager |
| `observability/install-grafana.sh` / `.ps1` | cluster local avulso (Kind/Minikube) sem Terraform | os mesmos componentes, com os mesmos nomes de release, reaproveitando os values do módulo. Sem StorageClass `gp3` (usa a padrão do cluster) e sem roteamento do Alertmanager |

Os dois caminhos usam os mesmos nomes de Service e os mesmos uids de datasource
(`prometheus`, `loki`, `tempo`), então o dashboard da aplicação funciona igual nos dois —
e também no Docker Compose. A única diferença visível é o nome do release do
kube-prometheus-stack: `monitoring-grafana` pelo script, `kube-prometheus-stack-grafana`
pelo Terraform.

O módulo Terraform é aplicado junto com o cluster:

    terraform -chdir=environments/prod apply

Ele expõe o endpoint OTLP no output `otel_collector_endpoint`, que é o valor já
configurado em `OTEL_EXPORTER_OTLP_ENDPOINT` nos overlays da aplicação.

## Destino dos alertas

Sem configuração, o Alertmanager sobe com o receiver `null`: as regras continuam sendo
avaliadas e os alertas aparecem na interface do Alertmanager, mas nada é enviado para
fora. Para notificar a equipe, informe um webhook — o valor é sensível e não deve ser
commitado:

    export TF_VAR_alertmanager_slack_webhook_url="https://hooks.slack.com/services/..."
    terraform -chdir=environments/prod apply

Alternativa sem Slack:

    export TF_VAR_alertmanager_webhook_url="https://exemplo.interno/alertas"

Com destino configurado, o roteamento separa as severidades: `critical` agrupa em 10
segundos e repete a cada 1 hora; `warning` repete a cada 12 horas.

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
k8s/observability/probe.yaml, o Prometheus consulta /health/ready e alimenta os painéis
de uptime e o alerta correspondente. node-exporter fornece métricas do nó e não
substitui cAdvisor para os containers.

Logs e traces centralizados vêm de Loki, Tempo e OpenTelemetry Collector, instalados
tanto pelo módulo Terraform quanto pelo script, e já apontados pela variável
`OTEL_EXPORTER_OTLP_ENDPOINT` dos overlays da aplicação
(`http://opentelemetry-collector.monitoring.svc.cluster.local:4318`). São eles que
alimentam os painéis "Logs estruturados (JSON)" e "Traces recentes" do dashboard.

O dashboard é provisionado pela aplicação em
observability/grafana/dashboards/techchallenge-observability.json.

## Datadog opcional para AWS

O Datadog permanece versionado como alternativa para um eventual ambiente AWS/EKS;
não é necessário para aceitar os requisitos cobertos pelo stack Prometheus + Grafana.
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

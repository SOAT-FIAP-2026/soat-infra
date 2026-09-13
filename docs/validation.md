# Validação — 07/09/2026

O repositório possui Terraform e pipelines, mas deploy funcional não está comprovado.
Esta revisão modificou documentação; as correções abaixo ainda estão pendentes.

## Verificações

- helm template com observability/kube-prometheus-values.yaml passou usando o chart
  90.0.0. O datasource tem uid prometheus e os seletores incluem os ServiceMonitors e
  PrometheusRules da aplicação.
- bash -n observability/install-grafana.sh passou usando Git Bash.
- bash -n observability/install-datadog.sh passou após a correção dos escapes shell nesta rodada.
- terraform fmt -check -recursive falhou em environments/dev/main.tf.
- terraform validate não foi concluído: após init -backend=false -lockfile=readonly,
  dev reportou checksums incompatíveis com o provider no Windows; prod precisa criar
  ou atualizar lock. Preparar dependências e repetir validate. Nenhum apply foi executado.
- Docker Engine indisponível e kubectl sem contextos nesta máquina: deploy local,
  readiness, CPU/memória e dashboards em execução ainda não validados.
- GitHub: main sem proteção; soat-architecture com permissão write.
- Último [Terraform Deploy consultado](https://github.com/SOAT-FIAP-2026/soat-infra/actions/runs/33330203865)
  falhou na etapa Configure AWS Credentials.

## Pendências

1. Corrigir fmt, preparar locks Windows/Linux e validar os ambientes com providers instalados.
2. Proteger main e exigir PR; definir homologação, ausente dos triggers atuais.
3. Resolver credenciais do pipeline e validar deploy no ambiente escolhido.
4. Criar cluster Minikube/Kind para demonstração: emulação EKS no Floci não executa pods.
5. Disponibilizar o Compose compartilhado do Floci referenciado pelo README, ausente
   na raiz atual do workspace, ou corrigir esse procedimento.
6. Fixar versão do chart validada e definir persistência e recursos do stack local.
7. Instalar recursos da aplicação e validar consultas/alertas com dados sintéticos.
8. Executar o stack e validar uptime HTTP, entrega ao receiver local e coleta/armazenamento
   de logs/traces. O Probe da aplicação usa o Blackbox Exporter e precisa de cluster ativo.
9. Corrigir script opcional Datadog antes de usá-lo.

A aplicação contém o relatório integrado em docs/validation-report.md no repositório
fase1-tech-challenge. A escolha local não remove a exigência de deploy em nuvem do
enunciado; a documentação AWS representa arquitetura alvo, não ambiente ativo comprovado.

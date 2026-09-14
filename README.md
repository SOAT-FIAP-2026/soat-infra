# Tech Challenge - Infraestrutura Kubernetes & Load Balancer (Terraform)

Consulte a [validação de 07/09/2026](docs/validation.md) para limites do ambiente local,
resultados das verificações e pendências de CI/CD e proteção de branches.

Repositório responsável pelo provisionamento da infraestrutura Kubernetes (EKS), rede, observabilidade e **Application Load Balancer (ALB)** na AWS utilizando **Terraform**.
Faz parte da Fase 3 do Tech Challenge — repositório dedicado à infraestrutura central do cluster Kubernetes e exposição de serviços.

---

## 🚀 Tecnologias

- [Terraform](https://www.terraform.io/) (>= 1.5.0)
- [AWS (Amazon Web Services)](https://aws.amazon.com/): VPC, Subnets, EKS, Application Load Balancer (ALB), IAM, Security Groups
- [Amazon EKS](https://aws.amazon.com/eks/) (v1.35) com Managed Node Group
- [AWS Application Load Balancer (ALB)](https://aws.amazon.com/elasticloadbalancing/application-load-balancer/): Exposição pública gerenciada via Terraform
- Helm provider do Terraform para orquestração da stack de observabilidade
- **Prometheus & Grafana**: Coleta de métricas e visualização de dashboards
- **Loki & Grafana Tempo**: Centralização de logs estruturados e distributed tracing
- **OpenTelemetry Collector**: Ingestão de telemetria da aplicação via OTLP (`:4318`)
- **Blackbox Exporter**: Monitoramento de uptime e sondas HTTP
- [Floci / LocalStack](https://github.com/floci/floci) (emulação local em Dev)

---

## 🏛️ Arquitetura

O Terraform neste repositório provisiona:

- **VPC & Rede:** 2 subnets públicas em AZs distintas (`sa-east-1a` e `sa-east-1b`), Internet Gateway e Route Tables públicas associadas.
- **IAM Roles:** Perfis gerenciados para o EKS Control Plane e Node Group com as policies necessárias (`AmazonEKSClusterPolicy`, `AmazonEKSWorkerNodePolicy`, `AmazonEKS_CNI_Policy`, `AmazonEC2ContainerRegistryReadOnly`, driver EBS CSI).
- **EKS Cluster:** Cluster Kubernetes gerenciado com Node Group em instâncias `t3.small` (3 nós em produção para comportar a carga de pods de sistema, observabilidade e aplicação).
- **Application Load Balancer (ALB):** ALB público provisionado via Terraform com listeners nas portas `80` (API) e `3000` (Grafana), associado diretamente aos nós do EKS via Target Groups e NodePorts (`30080` e `30300`), eliminando o uso de Classic ELBs do K8s e evitando travamento no `terraform destroy`.
- **Stack de Observabilidade:** Namespace `monitoring` com Prometheus, Grafana, Alertmanager, Loki, Tempo e OTel Collector com volumes EBS persistentes (`gp3`).

### Diagrama de Arquitetura

```
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                    AWS (sa-east-1)                                     │
│                                                                                        │
│   ┌────────────────────────────────────────────────────────────────────────────────┐   │
│   │                 Application Load Balancer (Terraform - ALB)                    │   │
│   │                 fiap-soat-terraform-alb-*.sa-east-1.elb.amazonaws.com          │   │
│   └───────────────────────┬────────────────────────────────┬───────────────────────┘   │
│                           │ :80                            │ :3000                     │
│                           ▼                                ▼                           │
│               ┌───────────────────────┐        ┌───────────────────────┐               │
│               │ Target Group API      │        │ Target Group Grafana  │               │
│               │ NodePort: 30080       │        │ NodePort: 30300       │               │
│               │ Path: /health/live    │        │ Path: /api/health     │               │
│               └───────────┬───────────┘        └───────────┬───────────┘               │
│                           │                                │                           │
│   ┌───────────────────────▼────────────────────────────────▼───────────────────────┐   │
│   │                                VPC (10.0.0.0/16)                               │   │
│   │                                                                                │   │
│   │   Subnet AZ-1a (10.0.0.0/20)               Subnet AZ-1b (10.0.16.0/20)         │   │
│   │   ┌──────────────────────────────────┐     ┌─────────────────────────────────┐ │   │
│   │   │  EKS Node 1 & Node 2 (t3.small)  │     │  EKS Node 3 (t3.small)          │ │   │
│   │   └─────────────────┬────────────────┘     └────────────────┬────────────────┘ │   │
│   │                     │                                       │                  │   │
│   │                     └───────────────────┬───────────────────┘                  │   │
│   │                                         ▼                                      │   │
│   │   ┌────────────────────────────────────────────────────────────────────────┐   │   │
│   │   │                        Cluster EKS (v1.35)                             │   │   │
│   │   │                                                                        │   │   │
│   │   │   Namespace: techchallenge                                             │   │   │
│   │   │   ┌───────────────────────────────────────────────────────────────┐    │   │   │
│   │   │   │  Pod API .NET 8 (Clean Architecture)                          │    │   │   │
│   │   │   │  - Service NodePort: 30080                                    │    │   │   │
│   │   │   │  - Tracing OTLP HTTP → OTel Collector (:4318)                 │    │   │   │
│   │   │   └───────────────────────────────┬───────────────────────────────┘    │   │   │
│   │   │                                   │                                    │   │   │
│   │   │   Namespace: monitoring           ▼                                    │   │   │
│   │   │   ┌───────────────────────────────────────────────────────────────┐    │   │   │
│   │   │   │  OpenTelemetry Collector (:4318)                              │    │   │   │
│   │   │   │  kube-prometheus-stack (Prometheus, Alertmanager, NodeExp)    │    │   │   │
│   │   │   │  Grafana UI (Service NodePort: 30300)                         │    │   │   │
│   │   │   │  Grafana Loki (Logs) & Grafana Tempo (Traces)                 │    │   │   │
│   │   │   └───────────────────────────────────────────────────────────────┘    │   │   │
│   │   └────────────────────────────────────────────────────────────────────────┘   │   │
│   └────────────────────────────────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 📁 Estrutura do Repositório

```
tech-challenge-infra-k8s/
├── modules/
│   ├── networking/       # VPC, Subnets públicas, IGW, Route Tables e Security Group
│   ├── iam/              # IAM Roles e Policies do EKS e OIDC EBS CSI
│   ├── eks/              # EKS Cluster, Node Group (t3.small), Access Entries
│   ├── load-balancer/    # ALB compartilhado, Target Groups (API/Grafana) e Listeners
│   └── observability/    # Helm: Prometheus, Grafana (NodePort 30300), Loki, Tempo, OTel
│       └── values/       # Values de cada componente da stack
├── environments/
│   ├── dev/              # Desenvolvimento local (Floci compartilhado)
│   └── prod/             # Produção na AWS (backend S3 remoto)
│       ├── providers.tf  # Backend S3, provider AWS, kubernetes, helm
│       ├── main.tf       # Orquestração dos módulos na AWS
│       ├── variables.tf  # Variáveis de produção
│       └── outputs.tf    # URLs públicas do ALB, dados de rede e endpoints
```

---

## 📋 Outputs Disponíveis

Estes outputs são gerados no `terraform apply` e consumidos por outros módulos (como o banco de dados via `terraform_remote_state`):

| Output | Descrição | Exemplo |
|---|---|---|
| `alb_dns_name` | Hostname público do Application Load Balancer | `fiap-soat-terraform-alb-*.sa-east-1.elb.amazonaws.com` |
| `api_swagger_url` | URL direta para o Swagger UI da API | `http://<alb-dns>/swagger` |
| `api_url` | Endpoint raiz da API | `http://<alb-dns>` |
| `grafana_url` | URL direta para a interface do Grafana | `http://<alb-dns>:3000` |
| `otel_collector_endpoint` | Endpoint interno de ingestão OTLP no K8s | `http://opentelemetry-collector.monitoring.svc.cluster.local:4318` |
| `vpc_id` | ID da VPC criada | `vpc-072e043dd5fc4fb25` |
| `subnet_ids` | Lista com os IDs das Subnets públicas | `["subnet-...", "subnet-..."]` |
| `security_group_id` | ID do Security Group dos nós do EKS | `sg-021bb6c63f447ca27` |
| `eks_cluster_name` | Nome do cluster EKS | `eks-fiap-soat-terraform` |

---

## 🛠️ Passo a Passo Completo: Como Rodar do Zero

### Pré-Requisitos
1. **AWS CLI v2** configurado com credenciais válidas (`aws configure`).
2. **Terraform >= 1.5.0** instalado.
3. **kubectl >= 1.28** instalado.
4. **Helm 3** instalado.
5. **gettext-base** (`envsubst`) instalado no Linux/macOS.
6. **Docker** logado localmente (`docker login`).

---

### Passo 1: Provisionar EKS, ALB e Observabilidade
Execute o Terraform no ambiente de produção deste repositório:
```bash
cd environments/prod
terraform init
terraform apply -auto-approve
```
*Tempo aproximado:* 15 a 20 minutos (tempo padrão da AWS para criar o Control Plane do EKS e o ALB).

---

### Passo 2: Configurar o Acesso ao EKS via Kubectl
Atualize o arquivo `~/.kube/config` para apontar para o novo cluster:
```bash
aws eks update-kubeconfig \
  --name eks-fiap-soat-terraform \
  --region sa-east-1
```
Confirme se os 3 nós do Node Group estão com status `Ready`:
```bash
kubectl get nodes
```

---

### Passo 3: Provisionar o Banco de Dados RDS PostgreSQL
No repositório do banco de dados, inicialize e aplique o Terraform. O RDS obtém os IDs de VPC, Subnets e Security Groups **automaticamente** via Remote State do S3:
```bash
cd "../../../tech-challenge-infra-db/environments/prod"
terraform init
terraform apply -auto-approve
```
*Tempo aproximado:* 5 a 10 minutos.

---

### Passo 4: Instalar Monitores e Dashboards no Kubernetes
No repositório da aplicação, aplique os recursos de monitoramento (ServiceMonitors, PrometheusRules e ConfigMap do Grafana Dashboard):
```bash
cd "../../../fase1-tech-challenge"
./k8s/observability/install.sh
```

---

### Passo 5: Fazer o Deploy da Aplicação .NET
Execute o script de deploy automatizado:
```bash
cd "../../../fase1-tech-challenge"
./k8s/overlays/aws/deploy.sh
```
O script automatiza todas as dependências:
- Consulta o endpoint do RDS PostgreSQL ativo via AWS CLI.
- Gera o `secrets.yaml` com encoding `base64 -w0` (sem quebras de linha).
- Injeta o segredo de autenticação do Docker Hub a partir de `~/.docker/config.json`.
- Aplica os manifestos Kubernetes e aguarda o pod ficar `Ready`.

---

## 🔍 Validação e URLs de Acesso

Após a conclusão dos passos acima, todos os serviços estarão acessíveis através do Application Load Balancer:

| Serviço | URL de Acesso | Porta | Status Esperado |
|---|---|---|---|
| **API Swagger UI** | `http://<alb-dns>/swagger` | 80 | **HTTP 200 OK** |
| **API Health Check** | `http://<alb-dns>/health/live` | 80 | **HTTP 200 OK** |
| **Grafana UI** | `http://<alb-dns>:3000` | 3000 | **HTTP 200 OK** |

### Comandos de Teste Rápido
```bash
# Obter DNS do ALB
ALB_DNS=$(terraform -chdir="environments/prod" output -raw alb_dns_name)

# Validar Swagger da API
curl -s -L -o /dev/null -w "Swagger HTTP Status: %{http_code}\n" http://${ALB_DNS}/swagger

# Validar Grafana
curl -s -L -o /dev/null -w "Grafana HTTP Status: %{http_code}\n" http://${ALB_DNS}:3000

# Checar logs e envio de traces da API para o OTel Collector
kubectl logs deployment/api -n techchallenge --tail=20
```

---

## 🛑 Como Destruir a Infraestrutura com Segurança

A destruição gerenciada pelo Terraform não causa mais erros de dependência. Para destruir todos os recursos de forma limpa, siga a ordem:

1. **Remover os pods e serviços da aplicação:**
   ```bash
   kubectl delete namespace techchallenge
   ```
2. **Destruir o banco de dados RDS:**
   ```bash
   cd "../tech-challenge-infra-db/environments/prod"
   terraform destroy -auto-approve
   ```
3. **Destruir o cluster EKS, ALB e componentes de rede:**
   ```bash
   cd "../tech-challenge-infra-k8s/environments/prod"
   terraform destroy -auto-approve
   ```

---

## 🔗 Repositórios Relacionados

| Repositório | Descrição |
|---|---|
| [fase1-tech-challenge](https://github.com/SOAT-FIAP-2026/fase1-tech-challenge) | Aplicação principal (.NET 8 Clean Architecture) executando no EKS |
| [tech-challenge-infra-db](https://github.com/SOAT-FIAP-2026/tech-challenge-infra-db) | Infraestrutura do Banco de Dados Gerenciado (AWS RDS PostgreSQL) |

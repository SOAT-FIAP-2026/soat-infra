# Tech Challenge - Infraestrutura Kubernetes (Terraform)

Repositório responsável pelo provisionamento da infraestrutura Kubernetes (EKS) na AWS utilizando **Terraform**.
Faz parte da Fase 3 do Tech Challenge — repositório dedicado à infraestrutura do cluster Kubernetes.

## Tecnologias

- [Terraform](https://www.terraform.io/)
- [AWS (Amazon Web Services)](https://aws.amazon.com/)
- [Amazon EKS](https://aws.amazon.com/eks/)
- [Floci / LocalStack](https://github.com/floci/floci) (emulação local)
- [Docker Compose](https://docs.docker.com/compose/)
- [GitHub Actions](https://github.com/features/actions)

## Arquitetura

O Terraform neste repositório provisiona:

- **VPC** com 2 subnets públicas em AZs distintas, Internet Gateway e Route Tables.
- **IAM Roles** para o EKS Control Plane e Node Group, com as policies necessárias.
- **EKS Cluster** (v1.35) com Node Group (t3.micro, 1-3 nodes), Access Entries para o IAM User de deploy.
- **Security Group** dedicado para o cluster EKS.

### Diagrama de Componentes

```
┌─────────────────────────────────────────────────────┐
│                    AWS (sa-east-1)                   │
│                                                     │
│  ┌───────────────────────────────────────────────┐  │
│  │                VPC (10.0.0.0/16)              │  │
│  │                                               │  │
│  │  ┌──────────────┐    ┌──────────────┐        │  │
│  │  │ Subnet AZ-1a │    │ Subnet AZ-1b │        │  │
│  │  └──────┬───────┘    └──────┬───────┘        │  │
│  │         │                   │                 │  │
│  │  ┌──────┴───────────────────┴───────┐        │  │
│  │  │         EKS Cluster (v1.35)      │        │  │
│  │  │  ┌─────────────────────────────┐ │        │  │
│  │  │  │    Node Group (t3.micro)    │ │        │  │
│  │  │  │    min: 1 | max: 3          │ │        │  │
│  │  │  └─────────────────────────────┘ │        │  │
│  │  └──────────────────────────────────┘        │  │
│  │                                               │  │
│  └───────────────────────────────────────────────┘  │
│                                                     │
│  ┌───────────────┐  ┌────────────────────────────┐  │
│  │  IAM Roles    │  │  S3 (Terraform State)      │  │
│  │  - Cluster    │  │  key: k8s/terraform.tfstate │  │
│  │  - Node Group │  └────────────────────────────┘  │
│  └───────────────┘                                  │
└─────────────────────────────────────────────────────┘
```

## Estrutura do Repositório

```
tech-challenge-infra-k8s/
├── modules/
│   ├── networking/     # VPC, Subnets, IGW, Route Tables, Security Group
│   ├── iam/            # IAM Roles e Policy Attachments do EKS
│   └── eks/            # EKS Cluster, Node Group, Access Entries
├── environments/
│   ├── dev/            # Desenvolvimento local (Floci compartilhado)
│   │   ├── docker-compose.yml   # Referência → usar o Floci da raiz do workspace
│   │   ├── providers.tf         # Endpoints apontam para localhost:4566
│   │   ├── main.tf              # Orquestra módulos contra Floci
│   │   ├── variables.tf         # Defaults seguros para teste local
│   │   └── outputs.tf
│   └── prod/           # Produção na AWS
│       ├── providers.tf         # Backend S3, provider AWS real
│       ├── main.tf              # Orquestra módulos na AWS
│       ├── variables.tf         # Variáveis de produção
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── .github/workflows/
    ├── pr.yml          # CI: terraform fmt, validate, plan
    └── deploy.yml      # CD: terraform apply
```

## Ambientes

### Dev (Local com Floci)

O ambiente de desenvolvimento emula os serviços AWS localmente usando [Floci](https://github.com/floci/floci).
O estado do Terraform é armazenado **localmente** (`terraform.tfstate`).

> **Nota:** O Floci é uma instância **compartilhada** entre todos os repos de infra.
> Suba-o uma única vez na raiz do workspace (`FIAP - TC/`).

```bash
# 1. Subir o Floci compartilhado (se ainda não estiver rodando)
cd "FIAP - TC/"
docker compose up -d

# 2. Rodar Terraform
cd tech-challenge-infra-k8s/environments/dev
terraform init
terraform plan
terraform apply

# 3. Verificar outputs
terraform output

# Para destruir recursos emulados
terraform destroy
```

**O que é validado em dev:**
- Sintaxe e estrutura dos módulos Terraform
- Wiring correto entre módulos (networking → iam → eks)
- Outputs e dependências inter-módulos

### Prod (AWS)

O ambiente de produção provisiona recursos reais na AWS.
O estado é armazenado **remotamente** em S3 (`k8s/terraform.tfstate`).

```bash
cd environments/prod

# Inicializar o Terraform (requer acesso ao bucket S3)
terraform init

# Verificar o plano de execução
terraform plan

# Aplicar a infraestrutura
terraform apply
```

## Isolamento de Estado

```
environments/
├── dev/
│   └── terraform.tfstate    ← Estado LOCAL (nunca comitado)
└── prod/
    └── (S3 remoto)          ← s3://fiap-soat-techchallenge-backend/k8s/terraform.tfstate
```

Cada ambiente tem seu próprio `terraform init` e `terraform apply`, executados **dentro da sua respectiva pasta**.
Os estados nunca são compartilhados entre ambientes.

## CI/CD e Deploy Automático

- **Pull Request** → `terraform fmt -check`, `terraform validate`, `terraform plan`
- **Merge para main** → `terraform apply -auto-approve`

## Outputs Disponíveis

Estes outputs são consumidos por outros repositórios via `terraform_remote_state`:

| Output | Descrição |
|---|---|
| `vpc_id` | ID da VPC |
| `vpc_cidr_block` | CIDR block da VPC |
| `subnet_ids` | IDs das subnets públicas |
| `security_group_id` | ID do Security Group principal |
| `eks_cluster_name` | Nome do cluster EKS |
| `eks_cluster_endpoint` | Endpoint do API server do EKS |

## Pré-Requisitos

### Dev (Local)
- Docker e Docker Compose instalados

### Prod (AWS)
- Conta ativa na AWS
- Chaves de acesso AWS configuradas localmente (`~/.aws/credentials`) ou no GitHub Secrets
- Terraform >= 1.5.0 instalado
- Bucket S3 `fiap-soat-techchallenge-backend` criado para o state backend
- IAM User `terraform-user` criado na conta AWS

## Repositórios Relacionados

| Repositório | Descrição |
|---|---|
| [fase1-tech-challenge](https://github.com/SOAT-FIAP-2026/fase1-tech-challenge) | Aplicação principal (.NET) executando em Kubernetes |
| [tech-challenge-infra-db](https://github.com/SOAT-FIAP-2026/tech-challenge-infra-db) | Infraestrutura do Banco de Dados Gerenciado (RDS) |

# Tech Challenge - Infraestrutura Kubernetes (Terraform)

Repositório responsável pelo provisionamento da infraestrutura Kubernetes (EKS) na AWS utilizando **Terraform**.
Faz parte da Fase 3 do Tech Challenge — repositório dedicado à infraestrutura do cluster Kubernetes.

## Tecnologias

- [Terraform](https://www.terraform.io/)
- [AWS (Amazon Web Services)](https://aws.amazon.com/)
- [Amazon EKS](https://aws.amazon.com/eks/)
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
│   └── prod/           # Configuração de produção (orquestra os módulos)
└── .github/workflows/
    ├── pr.yml          # CI: terraform fmt, validate, plan
    └── deploy.yml      # CD: terraform apply
```

## Pré-Requisitos

- Conta ativa na AWS
- Chaves de acesso AWS configuradas localmente (`~/.aws/credentials`) ou no GitHub Secrets (`AWS_ACCESS_KEY_ID` e `AWS_SECRET_ACCESS_KEY`)
- Terraform >= 1.5.0 instalado
- Bucket S3 `fiap-soat-techchallenge-backend` criado para o state backend
- IAM User `terraform-user` criado na conta AWS

## Execução Local

```bash
cd environments/prod

# Inicializar o Terraform
terraform init

# Verificar o plano de execução
terraform plan

# Aplicar a infraestrutura
terraform apply
```

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

## Repositórios Relacionados

| Repositório | Descrição |
|---|---|
| [fase1-tech-challenge](https://github.com/SOAT-FIAP-2026/fase1-tech-challenge) | Aplicação principal (.NET) executando em Kubernetes |
| [tech-challenge-infra-db](https://github.com/SOAT-FIAP-2026/tech-challenge-infra-db) | Infraestrutura do Banco de Dados Gerenciado (RDS) |

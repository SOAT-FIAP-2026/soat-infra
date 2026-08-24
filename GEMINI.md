# Agente Especialista — Infraestrutura Kubernetes (EKS)

Você é o **agente especialista em infraestrutura Kubernetes** para o projeto Tech Challenge (FIAP SOAT).
Este repositório gerencia a infraestrutura AWS para o cluster EKS usando Terraform.

---

## Contexto do Projeto

- **Fase:** Fase 3 do Tech Challenge
- **Ecossistema:** 3 repositórios independentes
  - `tech-challenge-infra-k8s` (ESTE REPO) — VPC, IAM, EKS
  - `tech-challenge-infra-db` — RDS PostgreSQL
  - `fase1-tech-challenge` — Aplicação .NET + Kubernetes manifests
- **IaC:** Terraform >= 1.5.0, AWS Provider ~> 5.0
- **CI/CD:** GitHub Actions

---

## Estrutura que você deve conhecer

```
tech-challenge-infra-k8s/
├── modules/
│   ├── networking/     # VPC, 2 Subnets públicas, IGW, Route Tables, SG
│   ├── iam/            # IAM Roles (Cluster + Node Group) + Policy Attachments
│   └── eks/            # EKS Cluster v1.35, Node Group, Access Entries
├── environments/
│   ├── dev/            # Floci/LocalStack (porta 4567, UI 4501)
│   │   ├── docker-compose.yml
│   │   ├── providers.tf    # fake creds → localhost:4567
│   │   ├── main.tf         # dummy terraform_user_arn
│   │   ├── variables.tf    # defaults seguros
│   │   └── outputs.tf
│   └── prod/           # AWS real (sa-east-1)
│       ├── providers.tf    # S3 backend: k8s/terraform.tfstate
│       ├── main.tf         # data source: aws_iam_user.terraform_user
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
└── .github/workflows/
    ├── pr.yml          # CI: fmt, validate, plan
    └── deploy.yml      # CD: apply
```

---

## Regras e Convenções

### Terraform

1. **Módulos são reutilizáveis** — não hardcode valores de ambiente dentro dos módulos. Use variáveis.
2. **Ambientes são isolados** — `environments/dev/` e `environments/prod/` NUNCA compartilham estado.
   - Dev: estado **local** (`terraform.tfstate` na pasta dev)
   - Prod: estado **remoto** no S3 (`k8s/terraform.tfstate`)
3. **Comentários em português** — todo o código Terraform usa comentários em português (pt-BR).
4. **Estilo de código:**
   - Headers de seção: `# ==============================================================================`
   - Separadores inline: `# --- Descrição -------`
   - Todas as variáveis têm `description`
   - Tags sempre incluem `Name` e `Project`
5. **Provider prod usa `default_tags`** com `Project`, `Environment` e `ManagedBy`.

### Ambiente Dev (Floci — instância compartilhada)

1. **Floci compartilhado:** instância ÚNICA na raiz do workspace (`FIAP - TC/docker-compose.yml`)
   - API: `localhost:4566`, UI: `localhost:4500`
   - Subir via: `cd "FIAP - TC/" && docker compose up -d`
2. **Credenciais fake:** `access_key = "test"`, `secret_key = "test"`
3. **Endpoints:** todos apontam para `http://localhost:4566`
4. **terraform_user_arn:** usar ARN fictício `arn:aws:iam::000000000000:user/terraform-user`
5. **Não usar data sources** que fazem lookup real (ex: `data.aws_iam_user`) — Floci pode não suportá-los.

### Ambiente Prod (AWS)

1. **Região:** `sa-east-1`
2. **Backend S3:** bucket `fiap-soat-techchallenge-backend`, key `k8s/terraform.tfstate`
3. **IAM User de deploy:** `terraform-user` (consultado via `data.aws_iam_user`)
4. **Instance types:** `t3.micro` (EKS nodes)
5. **Scaling:** min=1, max=3, desired=2

### Dependências Inter-Repositório

- O repo `tech-challenge-infra-db` (prod) consome os outputs deste repo via remote state:
  - `vpc_id`, `vpc_cidr_block`, `subnet_ids`, `security_group_id`
- Os manifests K8s (deployment, service, HPA) ficam no repo da aplicação (`fase1-tech-challenge/k8s/`)

---

## Fluxo de Trabalho

### Desenvolvimento Local
```bash
# Subir Floci compartilhado (se não estiver rodando)
cd "FIAP - TC/"
docker compose up -d

# Rodar Terraform
cd tech-challenge-infra-k8s/environments/dev
terraform init
terraform plan              # Valida módulos
terraform apply             # Cria recursos emulados
terraform destroy           # Limpa
```

### Deploy em Produção
```bash
cd environments/prod
terraform init              # Conecta ao S3 backend
terraform plan              # Revisa mudanças
terraform apply             # Aplica na AWS
```

### CI/CD (GitHub Actions)
- **PR → main:** `fmt -check` → `validate` → `plan`
- **Merge → main:** `apply -auto-approve`

---

## Ao criar novos módulos ou recursos

1. Crie o módulo em `modules/<nome>/` com `main.tf`, `variables.tf`, `outputs.tf`
2. Instancie no `main.tf` de **ambos** os ambientes (dev e prod)
3. Adapte o dev para usar valores fictícios ou flags condicionais (como `create_network_resources` no repo DB)
4. Exporte outputs relevantes em ambos os ambientes
5. Atualize o README.md com a nova estrutura

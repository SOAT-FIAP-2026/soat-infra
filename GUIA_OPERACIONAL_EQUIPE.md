# Guia Operacional da Equipe — Tech Challenge Fase 3

Guia prático para os 4 integrantes da equipe gerenciarem a infraestrutura AWS do projeto.

---

## Pré-Requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado com credenciais válidas (`aws configure`)
- Acesso à conta AWS do projeto na região `sa-east-1`

---

## Passo 0: Bootstrap Permanente (Executar UMA ÚNICA VEZ — feito pelo líder da equipe)

> ⚠️ **NUNCA execute `terraform destroy` nesta pasta.** O bootstrap é permanente.

```bash
cd soat-infra/bootstrap

terraform init

# Será solicitado: initial_jwt_secret (min 32 chars) e initial_db_password
terraform apply
```

Após o apply, anote o output `state_bucket_name` — ele será o nome do bucket nos backends dos módulos efêmeros. O nome segue o padrão: `soat-fiap-backend-tfstate`.

### Verificação

No Console AWS, confirme:
1. **S3** → Bucket `soat-fiap-backend-tfstate` existe com versionamento habilitado.
2. **DynamoDB** → Tabela `soat-fiap-terraform-locks` existe.
3. **Systems Manager → Parameter Store** → Os parâmetros em `/techchallenge/prod/*` estão visíveis.

---

## Passo 1: Subir o Ambiente Completo (Qualquer integrante)

A ordem de execução é importante pois existe dependência entre os módulos:

```bash
# 1. Subir EKS, ALB, VPC, Observabilidade e Lambda Auth
#    (na primeira vez a Lambda lerá valores placeholder do SSM para db_connection_string
#     até o RDS ser criado no passo seguinte)
cd soat-infra/environments/prod
terraform init
terraform apply -auto-approve

# 2. Subir o RDS PostgreSQL
#    (lê a VPC do EKS via Remote State e publica endpoint + connection string no SSM)
cd ../../../soat-db/environments/prod
terraform init
terraform apply -auto-approve

# 3. Re-apply do soat-infra para a Lambda capturar a connection string publicada pelo RDS
cd ../../../soat-infra/environments/prod
terraform apply -auto-approve
```

### Verificação

1. Acesse a URL do API Gateway (output `api_gateway_endpoint`) e faça:
   ```bash
   curl -X POST <API_GATEWAY_URL>/auth/token \
     -H "Content-Type: application/json" \
     -d '{"cpf": "529.982.247-25"}'
   ```
2. Use o `access_token` retornado para acessar a API Principal:
   ```bash
   curl -H "Authorization: Bearer <TOKEN>" \
     http://<ALB_DNS>/api/v1/ordens-servico
   ```
   Esperado: `200 OK`.

---

## Passo 2: Destruir o Ambiente (Para não gerar custos)

A ordem de destruição é **inversa** à de criação:

```bash
# 1. Destruir o RDS
cd soat-db/environments/prod
terraform destroy -auto-approve

# 2. Destruir EKS, ALB, VPC, Lambda e Observabilidade
cd ../../../soat-infra/environments/prod
terraform destroy -auto-approve
```

> ✅ O bucket S3, a tabela DynamoDB e os parâmetros SSM do bootstrap **continuam intactos**.
> Na próxima subida, basta repetir o Passo 1.

---

## Rotação de Senhas e Segredos

### Rotacionar o JWT Secret

```bash
# 1. Atualizar o valor no SSM
aws ssm put-parameter \
  --name "/techchallenge/prod/jwt_secret" \
  --value "NOVA-CHAVE-COM-PELO-MENOS-32-CARACTERES" \
  --type SecureString \
  --overwrite \
  --region sa-east-1

# 2. Re-apply do soat-infra para a Lambda pegar o novo valor
cd soat-infra/environments/prod
terraform apply -auto-approve
```

### Rotacionar a Senha do Banco

```bash
# 1. Atualizar no SSM
aws ssm put-parameter \
  --name "/techchallenge/prod/db_password" \
  --value "NOVA-SENHA-SEGURA" \
  --type SecureString \
  --overwrite \
  --region sa-east-1

# 2. Re-apply do soat-db para alterar a senha no RDS e atualizar a connection string
cd soat-db/environments/prod
terraform apply -auto-approve

# 3. Re-apply do soat-infra para a Lambda pegar a nova connection string
cd ../../../soat-infra/environments/prod
terraform apply -auto-approve
```

> **Nota:** A rotação requer `terraform apply` porque os valores são injetados como variáveis de ambiente na Lambda em deploy-time, não em runtime.

---

## Diagrama do Fluxo

```
Bootstrap (1x)     →   soat-infra (apply)   →   soat-db (apply)   →   soat-infra (re-apply)
  ├─ S3 Bucket           ├─ EKS                   ├─ RDS PostgreSQL     └─ Lambda lê SSM ✓
  ├─ DynamoDB             ├─ ALB                   ├─ SSM: db_endpoint
  └─ SSM Params           ├─ Lambda                └─ SSM: db_connection_string
                          ├─ API Gateway
                          ├─ Observabilidade
                          └─ SSM: alb_dns
```

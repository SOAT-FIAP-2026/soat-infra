# Guia Operacional da Equipe — Tech Challenge Fase 3

Guia prático para os integrantes da equipe gerenciarem e operarem a infraestrutura AWS, publicarem os serviços e validarem a solução ponta a ponta.

---

## Pré-Requisitos

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5.0
- [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html) configurado com credenciais válidas (`aws configure`) na região `sa-east-1`
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.28
- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) e utilitário `zip`
- `envsubst` (`sudo apt install gettext-base`)

---

## Passo 0: Bootstrap Permanente (Executar UMA ÚNICA VEZ)

> ⚠️ **NUNCA execute `terraform destroy` nesta pasta.** O bootstrap é permanente e armazena os estados remotos e parâmetros da equipe.

```bash
cd soat-infra/bootstrap

terraform init
terraform apply
```

Após o apply, confirme que foram criados:
1. **S3** → Bucket `soat-fiap-backend-tfstate` (versionamento e criptografia SSE).
2. **DynamoDB** → Tabela `soat-fiap-terraform-locks` (controle de concorrência).
3. **SSM Parameter Store** → Parâmetros base em `/techchallenge/prod/*`.

---

## Passo 1: Subida do Ecossistema Completo

A ordem de execução é linear, com cada módulo Terraform executado **uma única vez** (sem re-apply).

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ 1.1 soat-infra  │ ──> │  1.2 soat-db    │ ──> │ 1.3 Lambda Code │ ──> │ 1.4 K8s Deploy  │ ──> │ 1.5 Dashboards  │
│ VPC, EKS, ALB   │     │ RDS PostgreSQL  │     │ Publica C# .NET │     │ Migrations+API  │     │ Grafana+Metrics │
└─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘     └─────────────────┘
```

### 1.1. Subir a Infraestrutura Base (VPC, EKS, ALB, Observabilidade e Lambda)
```bash
cd soat-infra/environments/prod
terraform init
terraform apply -auto-approve
```
⏱️ *Tempo estimado: ~15 a 20 minutos.*

### 1.2. Subir o Banco de Dados (RDS PostgreSQL)
```bash
cd ../../../soat-db/environments/prod
terraform init
terraform apply -auto-approve
```
⏱️ *Tempo estimado: ~5 a 10 minutos.*  
*O RDS lê a VPC do EKS via Remote State e grava automaticamente a string de conexão em `/techchallenge/prod/db_connection_string` no SSM.*

### 1.3. Publicar o Código da Lambda de Autenticação
A Lambda foi provisionada na etapa 1.1 com suporte a resolução dinâmica de segredos no SSM. Agora, compile e publique o pacote .NET 8 com a regra de negócio:
```bash
cd ../../../lambda-auth-function/src/Fiap.TechChallenge.LambdaAuth

# Compilar e empacotar
dotnet publish -c Release -o /tmp/lambda-publish
cd /tmp/lambda-publish && zip -r /tmp/lambda-auth.zip .

# Atualizar o código da função na AWS
aws lambda update-function-code \
  --function-name fiap-soat-terraform-lambda-auth \
  --zip-file fileb:///tmp/lambda-auth.zip \
  --region sa-east-1
```

### 1.4. Iniciar a Aplicação e Executar Migrações no EKS
Conecte o `kubectl` ao cluster provisionado e faça o deploy dos manifestos. Ao inicializar, a API .NET executa automaticamente as migrações do EF Core e o seed dos clientes (incluindo o CPF padrão para testes):

# 1. Atualizar o contexto do kubectl com o nome correto do cluster
aws eks update-kubeconfig --name eks-fiap-soat-terraform --region sa-east-1

# 2. Executar o deploy automatizado da API (a partir da raiz ou de fase1-tech-challenge)
cd fase1-tech-challenge/k8s/overlays/aws
chmod +x deploy.sh
./deploy.sh
```

### 1.5. Aplicar Dashboards e Métricas da Aplicação (Grafana + Prometheus)
Para publicar os dashboards de negócio da oficina e configurar o scraping de métricas da API .NET no Prometheus:
```bash
cd fase1-tech-challenge/k8s/observability
chmod +x install.sh
./install.sh
```
*O script aplica o `ServiceMonitor` (coleta de `/metrics`), `PrometheusRule` (alertas corporativos), `Probe` (uptime) e publica o ConfigMap `techchallenge-grafana-dashboard` com a label `grafana_dashboard=1`, que o sidecar do Grafana descobre e importa automaticamente em poucos segundos.*

---

## Passo 2: Verificação e Testes Ponta a Ponta

Com todos os serviços ativos, execute os testes de validação integrados:

### 2.1. Teste de Autenticação na Borda (Edge Auth)
Obtenha o endpoint do API Gateway e requisite um token JWT informando um CPF válido:

```bash
API_GW_URL=$(cd soat-infra/environments/prod && terraform output -raw api_gateway_endpoint)

TOKEN_RESPONSE=$(curl -s -X POST "${API_GW_URL}/auth" \
  -H "Content-Type: application/json" \
  -d '{"cpf": "282.027.830-20"}')

echo "$TOKEN_RESPONSE"
```
**Resposta esperada (`200 OK`):**
```json
{
  "access_token": "eyJhbGciOi...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

### 2.2. Teste da API Principal Protegida
Extraia o `access_token` gerado e acesse uma rota protegida via Application Load Balancer:

```bash
TOKEN=$(echo "$TOKEN_RESPONSE" | grep -o '"access_token":"[^"]*' | cut -d'"' -f4)
ALB_DNS=$(cd soat-infra/environments/prod && terraform output -raw alb_dns)

curl -i -H "Authorization: Bearer $TOKEN" \
  "http://${ALB_DNS}/api/v1/ordens-servico"
```
**Resposta esperada:** `HTTP/1.1 200 OK`.

### 2.3. Acesso à Documentação Interativa (Swagger)
Abra no navegador para explorar todos os endpoints da oficina mecânica:
```text
http://<ALB_DNS>/swagger
```

### 2.4. Acesso aos Dashboards de Observabilidade (Grafana)
O Grafana está integrado ao mesmo Application Load Balancer na porta `3000`:
```text
http://<ALB_DNS>:3000
```
- **Usuário padrão:** `admin`
- **Dashboards pré-carregados:** Volume diário de OS, Tempo por etapa, Latência p95, Consumo de recursos K8s e Logs via Loki.

---

## Passo 3: Destruir o Ambiente (Para não gerar custos)

A ordem de destruição é **inversa** à de criação para respeitar as dependências de rede da AWS:

```bash
# 1. Destruir o RDS primeiro (libera as ENIs da VPC)
cd soat-db/environments/prod
terraform destroy -auto-approve

# 2. Destruir EKS, ALB, VPC, Lambda e Observabilidade
cd ../../../soat-infra/environments/prod
terraform destroy -auto-approve
```

> ✅ O bucket S3, a tabela DynamoDB e os parâmetros do Bootstrap **permanecem intactos** para o próximo teste.

---

## Rotação de Senhas e Segredos

### Rotacionar a Senha do Banco de Dados
A Lambda resolve a string de conexão diretamente no SSM em tempo de execução (*cold start*), não exigindo re-apply do `soat-infra`:

```bash
# 1. Atualizar a senha no SSM Parameter Store
aws ssm put-parameter \
  --name "/techchallenge/prod/db_password" \
  --value "NOVA-SENHA-SEGURA" \
  --type SecureString \
  --overwrite \
  --region sa-east-1

# 2. Re-apply do soat-db para aplicar a nova credencial no RDS e atualizar a connection string
cd soat-db/environments/prod
terraform apply -auto-approve

# 3. Reiniciar os pods da API no EKS para capturarem a nova senha
kubectl rollout restart deployment/api -n techchallenge
```

### Rotacionar o JWT Secret
```bash
# 1. Atualizar no SSM
aws ssm put-parameter \
  --name "/techchallenge/prod/jwt_secret" \
  --value "NOVA-CHAVE-COM-PELO-MENOS-32-CARACTERES" \
  --type SecureString \
  --overwrite \
  --region sa-east-1

# 2. Atualizar a variável de ambiente da Lambda
cd soat-infra/environments/prod
terraform apply -auto-approve

# 3. Reiniciar a aplicação para recarregar a assinatura
kubectl rollout restart deployment/api -n techchallenge
```

---

## Diagrama da Arquitetura Operacional

```
Bootstrap (Executado 1x)
  ├─ S3 Bucket (Backend de Estado)
  ├─ DynamoDB (State Locking)
  └─ SSM Parameter Store (/techchallenge/prod/*)
         │
         ▼
soat-infra (Executado 1x)
  ├─ VPC & Subnets Públicas
  ├─ Cluster AWS EKS (3 nós)
  ├─ Application Load Balancer (:80 API, :3000 Grafana)
  ├─ Stack Observabilidade (Prometheus, Grafana, Loki, Tempo)
  └─ AWS Lambda Auth & API Gateway (/auth)
         │
         ▼
soat-db (Executado 1x)
  ├─ AWS RDS PostgreSQL 16
  └─ Publicação automática no SSM (db_endpoint + db_connection_string)
         │
         ▼
lambda-auth-function (Deploy de Código)
  └─ Atualização do binário .NET 8 (leitura dinâmica do SSM via SDK)
         │
         ▼
fase1-tech-challenge (Deploy K8s)
  ├─ Migrations EF Core + Database Seed
  └─ Pods API .NET expostos via NodePort 30080
```

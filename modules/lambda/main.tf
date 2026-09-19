# ==============================================================================
# Módulo: Lambda — Função de Autenticação
# ==============================================================================
# Cria a IAM Role, o CloudWatch Log Group e a função Lambda.
# O pacote pode ser carregado de um arquivo local (dev/Floci) ou de um
# bucket S3 (prod), controlado pela variável `use_s3`.
# ==============================================================================

# --- IAM Role -----------------------------------------------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-auth-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_exec" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc_exec" {
  count      = length(var.subnet_ids) > 0 ? 1 : 0
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# --- IAM Policy: Permissão de leitura no SSM Parameter Store e KMS ------------
# Permite à Lambda resolver a connection string e outros parâmetros em runtime
resource "aws_iam_role_policy" "lambda_ssm" {
  name = "${var.function_name}-ssm-read"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/techchallenge/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- CloudWatch Log Group -----------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}

# --- Função Lambda ------------------------------------------------------------
resource "aws_lambda_function" "auth" {
  function_name = var.function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = var.handler
  runtime       = var.runtime
  timeout       = var.timeout
  memory_size   = var.memory_size

  # Origem do pacote: S3 (prod) ou arquivo local (dev)
  s3_bucket = var.use_s3 ? var.s3_bucket : null
  s3_key    = var.use_s3 ? var.s3_key : null
  filename  = var.use_s3 ? null : var.local_package_path

  source_code_hash = var.source_code_hash != "" ? var.source_code_hash : null

  environment {
    variables = var.environment_variables
  }

  dynamic "vpc_config" {
    for_each = length(var.subnet_ids) > 0 ? [1] : []

    content {
      subnet_ids         = var.subnet_ids
      security_group_ids = var.security_group_ids
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.basic_exec,
    aws_iam_role_policy_attachment.vpc_exec,
    aws_iam_role_policy.lambda_ssm,
    aws_cloudwatch_log_group.lambda,
  ]
}

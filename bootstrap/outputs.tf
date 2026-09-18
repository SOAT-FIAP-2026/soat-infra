# ==============================================================================
# Outputs — Bootstrap Permanente
# ==============================================================================

output "state_bucket_name" {
  description = "Nome do bucket S3 para armazenamento de estado"
  value       = aws_s3_bucket.state.id
}

output "dynamodb_table_name" {
  description = "Nome da tabela DynamoDB para locking"
  value       = aws_dynamodb_table.locks.name
}

output "backend_config_snippet" {
  description = "Bloco HCL pronto para copiar nos providers.tf dos módulos efêmeros"
  value       = <<-EOT
    backend "s3" {
      bucket         = "${aws_s3_bucket.state.id}"
      key            = "<SUBSTITUIR: k8s/terraform.tfstate ou db/terraform.tfstate>"
      region         = "${var.aws_region}"
      dynamodb_table = "${aws_dynamodb_table.locks.name}"
      encrypt        = true
    }
  EOT
}

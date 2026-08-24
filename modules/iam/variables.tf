variable "project_name" {
  description = "Nome do projeto — usado como prefixo nos recursos IAM"
  type        = string
}

variable "create_policy_attachments" {
  description = "Define se os policy attachments (AWS managed policies) devem ser criados. False para ambientes locais (Floci/LocalStack) que não possuem as managed policies."
  type        = bool
  default     = true
}

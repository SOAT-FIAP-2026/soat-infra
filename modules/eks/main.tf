# ==============================================================================
# Módulo: eks
# Responsável por: EKS Cluster, Node Group e Access Entries
# ==============================================================================

# --- EKS Cluster --------------------------------------------------------------
resource "aws_eks_cluster" "main" {
  name    = "eks-${var.project_name}"
  version = "1.35"

  dynamic "access_config" {
    for_each = var.create_access_entries ? [1] : []
    content {
      authentication_mode = "API"
    }
  }

  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }

  # Garante que as policies IAM existam antes de criar/destruir o cluster
  depends_on = [var.cluster_policy_attachment_dep]

  tags = {
    Name    = "eks-${var.project_name}"
    Project = var.project_name
  }
}

# --- EKS Node Group -----------------------------------------------------------
# Condicional: Floci não emula Node Groups (requer EC2 real).
# Em dev (create_node_group = false), apenas o cluster é criado.
resource "aws_eks_node_group" "main" {
  count           = var.create_node_group ? 1 : 0
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "node-group-${var.project_name}"
  node_role_arn   = var.node_group_role_arn
  subnet_ids      = var.subnet_ids
  disk_size       = 20
  instance_types  = var.instance_types

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  update_config {
    max_unavailable = 1
  }

  # Garante que as policies IAM existam antes de criar/destruir o node group
  depends_on = [
    var.cluster_policy_attachment_dep,
    var.node_cni_policy_attachment_dep,
    var.node_ecr_policy_attachment_dep,
  ]

  tags = {
    Name    = "node-group-${var.project_name}"
    Project = var.project_name
  }
}

# --- Access Entry: permissão de acesso ao cluster via IAM User ----------------
# Condicional: Floci não emula Access Entries/Policies do EKS.
resource "aws_eks_access_entry" "terraform_user" {
  count             = var.create_access_entries ? 1 : 0
  cluster_name      = aws_eks_cluster.main.name
  principal_arn     = var.terraform_user_arn
  kubernetes_groups = ["group-1", "group-2"]
  type              = "STANDARD"
}

resource "aws_eks_access_policy_association" "cluster_admin" {
  count         = var.create_access_entries ? 1 : 0
  cluster_name  = aws_eks_cluster.main.name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
  principal_arn = var.terraform_user_arn

  access_scope {
    type = "cluster"
  }
}

# --- EBS CSI Driver Addon ----------------------------------------------------
# Necessário para que PersistentVolumeClaims (PVCs) criem volumes EBS.
# Sem este addon, pods de Prometheus, Loki e Tempo não iniciam.
resource "aws_eks_addon" "ebs_csi_driver" {
  count                    = var.create_ebs_csi_driver ? 1 : 0
  cluster_name             = aws_eks_cluster.main.name
  addon_name               = "aws-ebs-csi-driver"
  service_account_role_arn = var.ebs_csi_role_arn

  depends_on = [aws_eks_node_group.main]

  tags = {
    Name    = "ebs-csi-${var.project_name}"
    Project = var.project_name
  }
}


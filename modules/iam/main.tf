# ==============================================================================
# Módulo: iam
# Responsável por: IAM Roles e Policy Attachments do EKS Cluster e Node Group
# ==============================================================================

# --- IAM Role: EKS Control Plane ----------------------------------------------
resource "aws_iam_role" "cluster" {
  name = "eks-cluster-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = ["sts:AssumeRole", "sts:TagSession"]
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
    }]
  })

  tags = {
    Name    = "eks-cluster-${var.project_name}"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster_AmazonEKSClusterPolicy" {
  count      = var.create_policy_attachments ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.cluster.name
}

# --- IAM Role: EKS Node Group -------------------------------------------------
resource "aws_iam_role" "node_group" {
  name = "eks-node-group-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = {
    Name    = "eks-node-group-${var.project_name}"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKSWorkerNodePolicy" {
  count      = var.create_policy_attachments ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEKS_CNI_Policy" {
  count      = var.create_policy_attachments ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.node_group.name
}

resource "aws_iam_role_policy_attachment" "node_group_AmazonEC2ContainerRegistryReadOnly" {
  count      = var.create_policy_attachments ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.node_group.name
}

# --- OIDC Provider para IRSA (IAM Roles for Service Accounts) ----------------
# Permite que Service Accounts do Kubernetes assumam IAM Roles na AWS.
# Necessário para o EBS CSI Driver e outros addons que precisam de permissões AWS.
data "tls_certificate" "eks" {
  count = var.create_ebs_csi_role ? 1 : 0
  url   = var.eks_oidc_issuer_url
}

resource "aws_iam_openid_connect_provider" "eks" {
  count           = var.create_ebs_csi_role ? 1 : 0
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks[0].certificates[0].sha1_fingerprint]
  url             = var.eks_oidc_issuer_url

  tags = {
    Name    = "oidc-${var.project_name}"
    Project = var.project_name
  }
}

# --- IAM Role: EBS CSI Driver (IRSA) -----------------------------------------
# O EBS CSI Driver precisa de permissões para criar/deletar volumes EBS.
# Sem esta Role, PersistentVolumeClaims ficam em estado Pending indefinidamente.
resource "aws_iam_role" "ebs_csi" {
  count = var.create_ebs_csi_role ? 1 : 0
  name  = "eks-ebs-csi-${var.project_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRoleWithWebIdentity"
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.eks[0].arn }
      Condition = {
        StringEquals = {
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
          "${replace(var.eks_oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = {
    Name    = "eks-ebs-csi-${var.project_name}"
    Project = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "ebs_csi_AmazonEBSCSIDriverPolicy" {
  count      = var.create_ebs_csi_role ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi[0].name
}


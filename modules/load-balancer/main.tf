# ==============================================================================
# Módulo: load-balancer
# Responsável por: Application Load Balancer (ALB), Target Groups e Listeners
# ==============================================================================
# Substitui os Classic ELBs criados dinamicamente pelo Kubernetes.
# O Terraform gerencia o ciclo de vida completo do ALB:
#   - Porta 80   → Target Group da API (NodePort 30080)
#   - Porta 3000 → Target Group do Grafana (NodePort 30300)
# Permite destroy limpo sem ENIs presas na VPC e exporta URLs públicas no outputs.
# ==============================================================================

# --- Security Group do ALB ---------------------------------------------------
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Security Group para o Application Load Balancer publico"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP para API"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP para Grafana"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permite saida para os nos do EKS (NodePort) e internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "${var.project_name}-alb-sg"
    Project = var.project_name
  }
}

# --- Application Load Balancer -----------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids

  enable_deletion_protection = false

  tags = {
    Name    = "${var.project_name}-alb"
    Project = var.project_name
  }
}

# --- Target Group: API .NET (NodePort 30080) ----------------------------------
resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-tg-api"
  port        = var.api_node_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.api_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg-api"
    Project = var.project_name
  }
}

# --- Target Group: Grafana (NodePort 30300) -----------------------------------
resource "aws_lb_target_group" "grafana" {
  name        = "${var.project_name}-tg-grafana"
  port        = var.grafana_node_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"

  health_check {
    enabled             = true
    path                = var.grafana_health_check_path
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name    = "${var.project_name}-tg-grafana"
    Project = var.project_name
  }
}

# --- Listener: Porta 80 (API) -------------------------------------------------
resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# --- Listener: Porta 3000 (Grafana) -------------------------------------------
resource "aws_lb_listener" "grafana" {
  load_balancer_arn = aws_lb.main.arn
  port              = 3000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.grafana.arn
  }
}

# --- Associação: Auto Scaling Group do EKS Node Group → Target Groups ---------
resource "aws_autoscaling_attachment" "api" {
  count                  = var.enable_autoscaling_attachment ? 1 : 0
  autoscaling_group_name = var.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.api.arn
}

resource "aws_autoscaling_attachment" "grafana" {
  count                  = var.enable_autoscaling_attachment ? 1 : 0
  autoscaling_group_name = var.autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.grafana.arn
}

# --- Regra de Ingress: Permite que o ALB envie tráfego para os nós do EKS (NodePort) ---
resource "aws_security_group_rule" "nodes_from_alb" {
  count                    = var.enable_node_security_group_rule ? 1 : 0
  type                     = "ingress"
  description              = "Permite trafego do ALB para os nos do EKS nas portas NodePort"
  from_port                = 30000
  to_port                  = 32767
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.alb.id
  security_group_id        = var.node_security_group_id
}

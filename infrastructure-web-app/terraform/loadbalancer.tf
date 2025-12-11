# Load Balancer for the dev-web-app module

resource "aws_lb" "app-server-lb" {
  name                       = "${local.name_prefix}-lb"
  subnets                    = module.vpc.public_subnets
  security_groups            = [aws_security_group.alb-sg.id]
  enable_deletion_protection = false


  # Ensure load balancer is destroyed before VPC
  # This helps prevent dependency violations
  lifecycle {
    create_before_destroy = true
  }
}

# HTTP listener - redirects to HTTPS
resource "aws_lb_listener" "app-server-listener-http" {
  load_balancer_arn = aws_lb.app-server-lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS listener - forwards to target group
resource "aws_lb_listener" "app-server-listener" {
  load_balancer_arn = aws_lb.app-server-lb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate_validation.app-server-cert-validation.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-server-tg.arn
  }
}

resource "aws_lb_target_group" "app-server-tg" {
  name        = "${local.name_prefix}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "instance" # Explicitly set target type to instance

  # Health check configuration - optimized for Apache health checks
  # Using "/" (root) is simpler - Apache serves index.html by default
  health_check {
    enabled             = true
    healthy_threshold   = 2         # Need 2 consecutive successes
    unhealthy_threshold = 3         # Mark unhealthy after 3 failures (give Apache time to start)
    timeout             = 10        # Increased timeout to 10 seconds (Apache needs time to respond)
    interval            = 30        # Check every 30 seconds (give more time between checks)
    path                = "/health" # Health check endpoint - doesn't require database
    protocol            = "HTTP"
    matcher             = "200"          # Accept HTTP 200 OK
    port                = "traffic-port" # Use the same port as target group (80)
  }

  # Ensure targets are deregistered slowly to avoid connection drops
  deregistration_delay = 30

  # Stickiness for session affinity (optional)
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }

  tags = {
    Name = "${local.name_prefix}-tg"
  }
}

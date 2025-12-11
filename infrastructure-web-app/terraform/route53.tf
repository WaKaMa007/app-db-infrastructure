# Lookup hosted zone
data "aws_route53_zone" "hosted_zone" {
  name         = var.hosted_zone_name
  private_zone = false
}

# Alias record pointing subdomain to ALB
resource "aws_route53_record" "app-server" {
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  name    = "${local.workspace_env}.${var.hosted_zone_name}"
  type    = "A"

  alias {
    name                   = aws_lb.app-server-lb.dns_name
    zone_id                = aws_lb.app-server-lb.zone_id
    evaluate_target_health = true
  }
}
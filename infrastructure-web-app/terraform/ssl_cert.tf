# SSL Certificate for the web-app module (workspace-specific)

resource "aws_acm_certificate" "app-server-cert" {
  domain_name       = "${local.workspace_env}.${var.hosted_zone_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "${local.name_prefix}-ssl-cert"
  }


}

resource "aws_route53_record" "app-server-cert-validation-record" {
  for_each = {
    for dvo in aws_acm_certificate.app-server-cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  zone_id = data.aws_route53_zone.hosted_zone.zone_id
  ttl     = 60
}

# Certificate Validation
resource "aws_acm_certificate_validation" "app-server-cert-validation" {
  certificate_arn         = aws_acm_certificate.app-server-cert.arn
  validation_record_fqdns = [for record in aws_route53_record.app-server-cert-validation-record : record.fqdn]
}
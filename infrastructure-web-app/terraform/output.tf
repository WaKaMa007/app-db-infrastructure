# Outputs for the dev-web-app module

output "alb_https_url" {
  description = "HTTPS URL for the sandbox environment (using domain name)"
  value       = "https://${aws_route53_record.app-server.name}"
}

output "launch_template_latest_version" {
  value = aws_launch_template.app-server-lt.latest_version
}

# External data source to get current instance IDs directly from AWS
# This queries AWS API directly every time Terraform runs, so it always returns current data
data "external" "asg_instances" {
  program = ["bash", "-c", <<-EOT
    ASG_NAME="${aws_autoscaling_group.app-server-asg.name}"
    REGION="${var.region}"
    
    # Get current instances from ASG (always fresh from AWS API)
    INSTANCES=$(aws autoscaling describe-auto-scaling-groups \
      --auto-scaling-group-names "$ASG_NAME" \
      --region "$REGION" \
      --query 'AutoScalingGroups[0].Instances[?LifecycleState==`InService` || LifecycleState==`Pending`].InstanceId' \
      --output text 2>/dev/null || echo "")
    
    # Convert space-separated to JSON array (works without jq)
    if [ -z "$INSTANCES" ] || [ "$INSTANCES" == "None" ]; then
      echo '{"instance_ids": "[]", "first_instance_id": "", "count": "0"}'
    else
      # Convert space-separated to JSON array manually (no jq dependency)
      FIRST_ID=$(echo "$INSTANCES" | awk '{print $1}')
      COUNT=$(echo "$INSTANCES" | wc -w)
      
      # Build JSON array manually and encode it as a JSON string
      # Terraform external data source requires all values to be strings
      JSON_ARRAY="["
      FIRST=true
      for INSTANCE in $INSTANCES; do
        if [ "$FIRST" = true ]; then
          JSON_ARRAY="$${JSON_ARRAY}\"$${INSTANCE}\""
          FIRST=false
        else
          JSON_ARRAY="$${JSON_ARRAY},\"$${INSTANCE}\""
        fi
      done
      JSON_ARRAY="$${JSON_ARRAY}]"
      
      # Escape the JSON array for embedding in another JSON string
      # Replace " with \", \ with \\, and newlines with \n
      ESCAPED_ARRAY=$(echo "$${JSON_ARRAY}" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g' | tr -d '\n')
      
      # Output as JSON with instance_ids as a JSON-encoded string
      echo "{\"instance_ids\": \"$${ESCAPED_ARRAY}\", \"first_instance_id\": \"$${FIRST_ID}\", \"count\": \"$${COUNT}\"}"
    fi
  EOT
  ]

  depends_on = [aws_autoscaling_group.app-server-asg]
}

# Output instance count
output "instance_count" {
  description = "Number of InService/Pending instances in the ASG"
  value       = try(tonumber(data.external.asg_instances.result.count), 0)
}

# Output SSM connection command for first instance (always uses current instance ID)
output "ssm_connect_command" {
  description = "Ready-to-use SSM Session Manager connection command (always uses current instance ID from AWS API)"
  value       = data.external.asg_instances.result.first_instance_id != "" ? "aws ssm start-session --target ${data.external.asg_instances.result.first_instance_id} --region ${var.region}" : "No instances available. Run: terraform apply"
}

output "db_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.db_credentials.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credentials.name
}

output "db_instance_id" {
  description = "RDS database instance identifier"
  value       = module.database.db_instance_identifier
}

# Prometheus and Grafana outputs
output "prometheus_instance_id" {
  description = "Prometheus server instance ID"
  value       = try(aws_instance.prometheus.id, null)
}

output "prometheus_private_ip" {
  description = "Prometheus server private IP address"
  value       = try(aws_instance.prometheus.private_ip, null)
}

output "grafana_instance_id" {
  description = "Grafana server instance ID"
  value       = try(aws_instance.grafana.id, null)
}

output "grafana_private_ip" {
  description = "Grafana server private IP address"
  value       = try(aws_instance.grafana.private_ip, null)
}

output "prometheus_url" {
  description = "Prometheus UI URL (via SSM port forwarding)"
  value       = try("http://${aws_instance.prometheus.private_ip}:9090", null)
}

output "grafana_url" {
  description = "Grafana UI URL (via ALB)"
  value       = try("https://grafana.${local.workspace_env}.${var.hosted_zone_name}", null)
}

output "grafana_private_url" {
  description = "Grafana UI URL (via SSM port forwarding)"
  value       = try("http://${aws_instance.grafana.private_ip}:3000", null)
}

output "access_instructions" {
  description = "Instructions to access Prometheus and Grafana"
  value       = <<-EOT
    Grafana Access:
      URL: https://grafana.${local.workspace_env}.${var.hosted_zone_name}
      Default credentials: admin / admin (CHANGE THIS!)
    
    Prometheus Access (via SSM):
      aws ssm start-session --target ${try(aws_instance.prometheus.id, "N/A")} \\
        --document-name AWS-StartPortForwardingSessionToRemoteHost \\
        --parameters '{"host":["${try(aws_instance.prometheus.private_ip, "")}"],"portNumber":["9090"],"localPortNumber":["9090"]}'
      Then open: http://localhost:9090
  EOT
}

# Infrastructure resource identifiers for CI/CD workflows
output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.app-server-asg.name
}

output "target_group_arn" {
  description = "Application target group ARN"
  value       = aws_lb_target_group.app-server-tg.arn
}

output "alb_arn" {
  description = "Application Load Balancer ARN"
  value       = aws_lb.app-server-lb.arn
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = aws_lb.app-server-lb.dns_name
}





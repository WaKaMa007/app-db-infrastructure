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
  value       = aws_secretsmanager_secret.db_credential.arn
}

output "secret_name" {
  description = "Name of the Secrets Manager secret"
  value       = aws_secretsmanager_secret.db_credential.name
}

output "db_instance_id" {
  description = "RDS database instance identifier"
  value       = module.database.db_instance_identifier
}





# Autoscaling for the dev-web-app module

resource "aws_launch_template" "app-server-lt" {
  name          = "${local.lt_prefix}-lt-${local.random_integer}"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = local.env_config.instance_type
  # Security group for app servers - allows traffic from ALB
  vpc_security_group_ids = [aws_security_group.app-server-sg.id]

  # IAM instance profile for S3 access
  iam_instance_profile {
    name = aws_iam_instance_profile.app-server-instance-profile.name
  }

  # Use bootstrap script to download full userdata from S3
  # This keeps user_data under 16KB limit and allows for larger scripts
  user_data = base64encode(templatefile("${path.module}/scripts/userdata_bootstrap.sh", {
    s3_bucket_name = aws_s3_bucket.app_assets.id
    region         = var.region
  }))

  # Ensure new versions become the default
  update_default_version = true

  # Ensure database, secrets, IAM profile, and S3 script are created before launch template
  depends_on = [
    module.database,
    aws_secretsmanager_secret_version.db_credentials,
    aws_iam_instance_profile.app-server-instance-profile,
    aws_s3_object.userdata_script # Ensure S3 script is uploaded before launch template
  ]

  # Tag specifications for volumes only
  # Instance tags are handled by ASG with propagate_at_launch for better reliability
  tag_specifications {
    resource_type = "volume"

    tags = {
      Name = "${local.name_prefix}-instance-volume"
    }
  }
}

resource "aws_autoscaling_group" "app-server-asg" {
  name = "${local.name_prefix}-asg"
  # TEMPORARY: Using public subnets for troubleshooting (instances need public IPs)
  # Change back to module.vpc.private_subnets when done troubleshooting
  vpc_zone_identifier = module.vpc.private_subnets # TEMPORARY - was: private_subnets
  target_group_arns   = [aws_lb_target_group.app-server-tg.arn]
  # Use ELB health checks to ensure instances are added to target group
  # ELB health checks verify the application is responding, not just instance running
  health_check_type         = "ELB" # Use target group health status
  health_check_grace_period = 600   # 10 minutes - give instances time to start (NAT Gateway adds latency)

  min_size         = local.env_config.min_size
  max_size         = local.env_config.max_size
  desired_capacity = local.env_config.desired_capacity

  launch_template {
    id      = aws_launch_template.app-server-lt.id
    version = aws_launch_template.app-server-lt.latest_version
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-instance"
    propagate_at_launch = true
  }

  termination_policies = ["OldestInstance", "Default"]

  # Instance refresh configuration - only triggers when launch template ID changes
  # or when manually started. Version-only changes are ignored via lifecycle block above.
  instance_refresh {
    strategy = "Rolling"

    preferences {
      skip_matching          = true # Skip refresh if instances already match the new launch template
      min_healthy_percentage = 50   # keep half healthy (1 of 2 instances)
      instance_warmup        = 120  # wait 2 minutes before marking healthy
      auto_rollback          = true # rollback if refresh fails
    }
  }

  depends_on = [
    aws_lb_target_group.app-server-tg,
    aws_lb.app-server-lb
  ]
}



# Trigger instance refresh when user_data changes
resource "null_resource" "instance_refresh_trigger" {
  # Trigger when userdata script file changes
  # Do NOT include launch_template_version - it changes on every terraform run
  triggers = {
    user_data_hash = local.user_data_hash                      # Trigger when userdata_client_app.sh changes
    asg_name       = aws_autoscaling_group.app-server-asg.name # For reference only
  }

  # Wait for ASG and launch template to be ready
  depends_on = [
    aws_autoscaling_group.app-server-asg,
    aws_launch_template.app-server-lt
  ]

  # Trigger instance refresh via AWS CLI
  provisioner "local-exec" {
    command = <<-EOT
      ASG_NAME="${aws_autoscaling_group.app-server-asg.name}"
      REGION="${var.region}"
      
      # Check if there's an active refresh first
      ACTIVE_REFRESH=$(aws autoscaling describe-instance-refreshes \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$REGION" \
        --query 'InstanceRefreshes[?Status==`InProgress` || Status==`Pending`].InstanceRefreshId' \
        --output text 2>/dev/null || echo "")
      
      if [ -n "$ACTIVE_REFRESH" ] && [ "$ACTIVE_REFRESH" != "None" ]; then
        echo "⚠️  Active instance refresh already in progress (ID: $ACTIVE_REFRESH)"
        echo "   Skipping new refresh. Wait for current one to complete."
        echo "   Monitor with: aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --region $REGION"
        exit 0
      fi
      
      echo "🔄 Starting instance refresh for ASG: $ASG_NAME (userdata.sh changed)"
      aws autoscaling start-instance-refresh \
        --auto-scaling-group-name "$ASG_NAME" \
        --region "$REGION" \
        --preferences "MinHealthyPercentage=50,InstanceWarmup=120,AutoRollback=false" \
        --output json
      
      echo "✅ Instance refresh started. Monitor progress with:"
      echo "   aws autoscaling describe-instance-refreshes --auto-scaling-group-name $ASG_NAME --region $REGION"
    EOT
  }
}


# Locals for the app_db module

locals {
  # Use Terraform workspace if available, otherwise fall back to environment variable
  workspace_env = terraform.workspace != "default" ? terraform.workspace : var.environment
  name_prefix   = "${var.name_prefix}-${local.workspace_env}"

  # Tier-specific prefixes
  app_prefix     = "${local.name_prefix}-server"
  db_prefix      = "${local.name_prefix}-db"
  alb_prefix     = "${local.name_prefix}-alb"
  asg_prefix     = "${local.name_prefix}-asg"
  lt_prefix      = "${local.name_prefix}-lt"
  sg_prefix      = "${local.name_prefix}-sg"
  ec2_prefix     = "${local.name_prefix}-instance-${random_integer.random.result}"
  random_integer = random_integer.random.result


  # Track user_data changes and trigger instance refresh automatically
  # Track changes to bootstrap script and userdata script
  bootstrap_script_hash = sha256(file("${path.module}/scripts/userdata_bootstrap.sh"))
  userdata_script_hash  = sha256(file("${path.module}/scripts/userdata_client_app.sh"))

  # Combined hash to trigger refresh when either script changes
  user_data_hash = sha256("${local.bootstrap_script_hash}${local.userdata_script_hash}")
}

resource "random_integer" "random" {
  min = 100000
  max = 999999
}
# AWS provider for the app_db module

terraform {
  required_version = ">= 1.0"

  backend "s3" {
    bucket = "terraform-state-backend879670"        # your bucket
    key    = "s3-tfstate-backend/terraform.tfstate" # path inside the bucket
    region = "us-east-1"
    #  dynamodb_table = "tf-locks-adebayo123"             # optional but recommended
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

provider "aws" {
  region = var.region
}

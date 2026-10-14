terraform {
  # 1.10+ is required for S3 native state locking (use_lockfile)
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # ── Step 2 of bootstrapping ───────────────────────────────────────────────
  # The first apply runs with LOCAL state (this block commented out), because
  # the bucket that will hold the state doesn't exist yet.
  # After the first apply:
  #   1. Uncomment this block and replace <ACCOUNT_ID> with your account ID
  #      (backend blocks can't use variables, so the name must be literal)
  #   2. Run: terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket       = "babysteps-tfstate-<ACCOUNT_ID>"
  #   key          = "bootstrap/terraform.tfstate"
  #   region       = "eu-central-1"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = var.project
      Stack     = "bootstrap"
      ManagedBy = "terraform"
    }
  }
}

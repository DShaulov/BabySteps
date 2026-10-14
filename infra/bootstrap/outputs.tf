output "account_id" {
  description = "AWS account ID."
  value       = local.account_id
}

output "region" {
  description = "Primary AWS region."
  value       = var.region
}

output "tfstate_bucket" {
  description = "S3 bucket for Terraform state. Use it in the backend block of every stack."
  value       = aws_s3_bucket.tfstate.bucket
}

output "github_plan_role_arn" {
  description = "Role assumed by GitHub Actions for terraform plan (store as a repo variable)."
  value       = aws_iam_role.github_plan.arn
}

output "github_deploy_role_arn" {
  description = "Role assumed by GitHub Actions for deploys (store as a repo variable)."
  value       = aws_iam_role.github_deploy.arn
}

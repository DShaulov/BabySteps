variable "project" {
  description = "Project name, used as a prefix for resource names (lowercase: S3 bucket names require it)."
  type        = string
  default     = "babysteps"
}

variable "region" {
  description = "Primary AWS region."
  type        = string
  default     = "eu-central-1"
}

variable "github_owner" {
  description = "GitHub user or organization that owns the repository."
  type        = string
  default     = "DShaulov"
}

variable "github_repo" {
  description = "GitHub repository name. Case-sensitive: it must match the OIDC token's sub claim exactly."
  type        = string
  default     = "BabySteps"
}

variable "alert_email" {
  description = "Email address that receives AWS budget alerts."
  type        = string

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.alert_email))
    error_message = "alert_email must be a valid email address."
  }
}

variable "monthly_budget_usd" {
  description = "Monthly spend (USD) above which an alert is sent."
  type        = number
  default     = 1
}

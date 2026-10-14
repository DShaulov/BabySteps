# Lets GitHub Actions authenticate to AWS with short-lived OIDC credentials
# instead of long-lived access keys.
#
# Two roles:
#   - plan:   read-only, assumable from pull requests (terraform plan)
#   - deploy: can change infrastructure, assumable only from main / GitHub environments

locals {
  repo       = "${var.github_owner}/${var.github_repo}"
  account_id = data.aws_caller_identity.current.account_id

  plan_role_name   = "${var.project}-github-plan"
  deploy_role_name = "${var.project}-github-deploy"
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

# ── Trust policies ──────────────────────────────────────────────────────────

data "aws_iam_policy_document" "plan_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Any branch, PR or environment of this repo may run a plan
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${local.repo}:*"]
    }
  }
}

data "aws_iam_policy_document" "deploy_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Only the main branch, or jobs bound to a GitHub environment.
    # (When a job uses `environment:`, the token's sub becomes
    # "repo:<owner>/<repo>:environment:<name>" instead of the branch ref.)
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "repo:${local.repo}:ref:refs/heads/main",
        "repo:${local.repo}:environment:dev",
        "repo:${local.repo}:environment:prod",
      ]
    }
  }
}

# ── Plan role (read-only) ───────────────────────────────────────────────────

resource "aws_iam_role" "github_plan" {
  name                 = local.plan_role_name
  assume_role_policy   = data.aws_iam_policy_document.plan_trust.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "github_plan_readonly" {
  role       = aws_iam_role.github_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# `terraform plan` acquires the state lock, which writes a .tflock object
data "aws_iam_policy_document" "plan_state_lock" {
  statement {
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.tfstate.arn}/*.tflock"]
  }
}

resource "aws_iam_role_policy" "github_plan_state_lock" {
  name   = "state-lock"
  role   = aws_iam_role.github_plan.id
  policy = data.aws_iam_policy_document.plan_state_lock.json
}

# ── Deploy role ─────────────────────────────────────────────────────────────

resource "aws_iam_role" "github_deploy" {
  name                 = local.deploy_role_name
  assume_role_policy   = data.aws_iam_policy_document.deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "deploy" {
  # Full access to the services this project uses (and nothing else: no EC2, RDS, VPC...)
  statement {
    sid = "ManageProjectServices"
    actions = [
      "s3:*",
      "cloudfront:*",
      "lambda:*",
      "apigateway:*",
      "dynamodb:*",
      "cognito-idp:*",
      "logs:*",
      "acm:*",
      "ssm:*",
    ]
    resources = ["*"]
  }

  # IAM only for roles/policies named with the project prefix
  statement {
    sid     = "ManageProjectIam"
    actions = ["iam:*Role*", "iam:*Policy*"]
    resources = [
      "arn:aws:iam::${local.account_id}:role/${var.project}-*",
      "arn:aws:iam::${local.account_id}:policy/${var.project}-*",
    ]
  }

  # ...except the CI roles themselves. Without this, the deploy role could
  # attach AdministratorAccess to itself (privilege escalation).
  statement {
    sid     = "DenyModifyingCiRoles"
    effect  = "Deny"
    actions = ["iam:*"]
    resources = [
      aws_iam_role.github_plan.arn,
      "arn:aws:iam::${local.account_id}:role/${local.deploy_role_name}",
    ]
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "deploy"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

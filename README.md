# BabySteps

A small PWA for logging a baby's feeds, diaper changes and sleep, used by two people. It runs on serverless AWS and is managed with Terraform.

```
Phone (PWA) ──► CloudFront ─┬─► S3                       (static React app)
                            └─► API Gateway ──► Lambda ──► DynamoDB
                                     │
                                  Cognito (JWT)
```

## Repository layout

| Path | Contents |
|---|---|
| `web/` | React + Vite PWA |
| `api/` | Lambda backend (TypeScript + Hono) |
| `infra/bootstrap/` | One-time setup: state bucket, GitHub OIDC roles, budget alert. Applied by hand. |
| `infra/modules/` | Reusable Terraform modules |
| `infra/envs/` | Root modules per environment (`dev`, `prod`) |
| `.github/workflows/` | CI/CD |

## Bootstrap (one time)

### Prerequisites

```bash
brew install awscli
aws configure sso          # or another admin profile; avoid long-lived access keys
export AWS_PROFILE=<profile-name>
aws sts get-caller-identity
```

### 1. Apply with local state

The state bucket doesn't exist yet, so the first apply stores state locally.

```bash
cd infra/bootstrap
cp terraform.tfvars.example terraform.tfvars   # set alert_email
terraform init
terraform plan
terraform apply
```

AWS sends an email asking you to confirm the budget alert subscription.

### 2. Migrate state into the new bucket

1. In `versions.tf`, uncomment the `backend "s3"` block and replace `<ACCOUNT_ID>` with the `account_id` output.
2. Migrate the state:

```bash
terraform init -migrate-state   # answer "yes" to copy local state to S3
rm terraform.tfstate terraform.tfstate.backup
```

### 3. Give GitHub Actions the role ARNs

```bash
gh variable set AWS_REGION       --body "$(terraform output -raw region)"
gh variable set AWS_PLAN_ROLE    --body "$(terraform output -raw github_plan_role_arn)"
gh variable set AWS_DEPLOY_ROLE  --body "$(terraform output -raw github_deploy_role_arn)"
gh variable set TF_STATE_BUCKET  --body "$(terraform output -raw tfstate_bucket)"
```

The ARNs aren't secrets. A role can only be assumed by workflows in this repo, because of the OIDC trust policy.

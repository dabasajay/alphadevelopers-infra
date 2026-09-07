# alphadevelopers-infra

Infrastructure for the POC estate. Terraform/OpenTofu manages AWS; Ansible manages
the Hostinger VM. Both run from a laptop only — nothing in GitHub can create or
change infrastructure.

## Shape

```
Route53 ──► CloudFront ──┬── default ──► S3 (SPA)
                         └── /api/*  ──► Lambda function URL (AWS_IAM + OAC)
                                              │
                                    srv1136595.hstgr.cloud
                                    ├── :24312 pgbouncer  (mTLS)  ──► Postgres (no host port)
                                    └── :24320 redis/app  (TLS)
```

Postgres and Redis live on the VM. One Postgres database + role per app; one Redis
container per app. Lambda runs outside a VPC and reaches both over the public
internet, gated by mutual TLS.

## Layout

| Path | Purpose |
|---|---|
| `terraform/modules/` | Generic, single-purpose building blocks |
| `terraform/services/shared/` | Route53 lookups, the one WAF ACL, backup bucket, GitHub OIDC provider |
| `terraform/services/resume-builder/` | Composes modules for one app |
| `terraform/envs/prod/` | Root config: backend, providers, locals, and module blocks only |
| `ansible/` | VM configuration (phase 2) |

Adding a POC app = a new `services/<app>/` folder, an entry in
`envs/prod/locals.tf`, and a module block in `envs/prod/main.tf`. Modules and
services are env-agnostic and take variables; everything env-specific is a
local, so there are no tfvars to supply.

## First run

Requires an AWS profile whose credentials expire — SSO is preferred over static keys.

```sh
export AWS_PROFILE=alphadevelopers
aws sso login

make bootstrap        # creates the state bucket; run once, outside Terraform
make init
make plan-shared      # shared publishes outputs the app services consume
make apply-shared
```

### Push a placeholder image before the first full apply

A container-image Lambda cannot be created against an empty ECR repository, so
the repo needs any image before `module.resume_builder` will apply.

```sh
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
REPO=$ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com/alphadevelopers-prod-resume-builder

aws ecr get-login-password --region ap-south-1 \
  | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.ap-south-1.amazonaws.com

docker pull public.ecr.aws/lambda/python:3.13
docker tag public.ecr.aws/lambda/python:3.13 $REPO:latest
docker push $REPO:latest
```

Then:

```sh
make plan
make apply
make output
```

The Lambda modules set `ignore_changes = [image_uri]`, so CI owns the deployed
image from that point on and Terraform will not roll it back.

## After apply

1. **Activate cost allocation tags.** In Billing → Cost allocation tags, activate
   `App`, `Env`, `Org`. Not retroactive, and takes ~24h to populate.
2. **Set the Lambda environment variables.** Terraform declares none and ignores
   the attribute, so the console is the only owner: database host, port, name,
   role and password, the Redis host and port, the JWT secret, the Google OAuth
   pair, and the PDF bucket name. Nothing here passes through Terraform state.
3. **Add the backup credentials to the VM.** `make output` prints the access key
   for pgBackRest. Retention is the last 3 fulls and only pgBackRest can enforce
   a count, so it holds `s3:DeleteObject` — which on a versioned bucket writes a
   delete marker and nothing more. `s3:DeleteObjectVersion` is granted to nobody,
   so the underlying versions stay immutable under Object Lock compliance mode
   and a compromised VM cannot destroy its own backups. S3 reclaims the storage
   14 days after pgBackRest retires a version.
4. **Set the GitHub deploy role.** `deploy_role_arn` from the output goes into the
   `resume-builder` repo as the OIDC role for its deploy workflow.
5. **Smoke-test a POST through CloudFront** before building on it — OAC signing of
   request bodies against an `AWS_IAM` function URL is the one unverified
   assumption in this design. If `POST /api/auth/login` returns 403
   `InvalidSignatureException`, the fallback is `AUTH_NONE` plus a
   CloudFront-injected secret header validated in middleware.

## Notes

- ACM certs and the WAF ACL are in `us-east-1` because CloudFront requires it.
  Everything else is `ap-south-1`, matching the Mumbai VM.
- SPA routing uses a CloudFront Function, not `custom_error_response` — the latter
  is distribution-wide and would rewrite real API 403s and 404s into `index.html`.
- WAF is off (`waf_enabled = false`). Until it is turned on, Lambda reserved
  concurrency is the only cap on a runaway bill, and there is no edge rate
  limiting — per-route limiting lives in the app's Redis limiter either way.
  Enabling it costs ~$8/month for one ACL shared by every distribution.
- When enabled, `AWSManagedRulesCommonRuleSet` stays off by default and
  Count-only: its `SizeRestrictions_BODY` rule blocks bodies over 8KB and would
  break resume saves.
- No database or Redis secret passes through Terraform, so none appear in state.

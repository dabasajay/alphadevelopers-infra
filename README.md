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
5. **OAC on an `AWS_IAM` function URL has two requirements that are easy to
   miss.** Both are handled, and both fail as a 403 that looks like a
   misconfigured distribution:
   - The function needs **two** grants, `lambda:InvokeFunctionUrl` *and*
     `lambda:InvokeFunction`. Function URLs created after October 2025 refuse
     the call with `AccessDeniedException` given only the first, even though
     the signature was accepted. `FunctionUrlAuthType` is rejected on the
     second action, so they cannot be one resource.
   - CloudFront signs the request but **does not hash the body**, and Lambda
     does not accept unsigned payloads. Any request with a body must send
     `x-amz-content-sha256` itself, or it fails with
     `InvalidSignatureException`. The SPA does this in `api/client.ts`; a
     bodyless request needs nothing.

## Database access for developers

A read-only web console per app, reached over an IAM-authenticated Session
Manager tunnel. Nothing is exposed: the console binds `127.0.0.1` on the VM and
the SSM agent dials out, so no inbound port is opened for any of it.

One-time setup per developer:

```sh
brew install --cask session-manager-plugin   # or the AWS bundle installer
```

Then, per session:

```sh
AWS_PROFILE=alphadevelopers aws ssm start-session \
  --target "$(aws ssm describe-instance-information \
      --query 'InstanceInformationList[0].InstanceId' --output text)" \
  --document-name alphadevelopers-prod-resume-builder-db-console \
  --parameters '{"localPortNumber":["8091"]}'
```

Leave it running and open <http://localhost:8091>. `make db-console` does the
same thing, in this repo and in the app repo. The port is 8091 rather than 8081
because the app repo's docker-compose publishes local pgweb on 8081, and reading
production while believing it is local seed data is a mistake worth designing
out.

What a developer can and cannot do:

- **Read every table** in their app's database, via `pg_read_all_data`.
- **Not write anything.** The role has `default_transaction_read_only = on`, so
  Postgres refuses the write itself. pgweb's own `--readonly` is only a keyword
  check on the query string and a CTE walks straight past it; the server-side
  setting is the guard that matters.
- **Not reach any other port.** `portNumber` is a literal in the session
  document, not a parameter, so it cannot be overridden. AWS's own
  `AWS-StartPortForwardingSession` does take it as a parameter, which is why
  that document is explicitly denied.
- **Not get a shell.** `StartSession` authorises against the document as well as
  the target, and every interactive document is denied, as is
  `ssm:SendCommand` — Run Command executes as root.
- **Not starve the app.** Its own role, `CONNECTION LIMIT 3`, and
  `statement_timeout = 15s`.

Sessions cost $0.05 each from 30 September 2026 and nothing before that, with no
duration component — so one tunnel left open all day costs the same as one
opened for a minute, and reopening it repeatedly is the only way to run the bill
up. At 3 developers opening it twice a day that is about $6.60/month; opening it
once and leaving it up halves that. The console itself is a ~30MB container on a
VM that is already paid for.

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
- The developer group carries `ReadOnlyAccess`, which cannot be narrowed. It
  grants `s3:Get*` on every bucket and `ssm:Get*` on every parameter, and
  `GetParameter` transparently decrypts a `SecureString` — together the
  encrypted backups and the passphrase that opens them. `datastore-guardrails`
  denies both, plus every SSM route to a shell on the datastore host.
- `pgbouncer`'s `client_tls_sslmode = verify-full` only requires *a* valid
  client certificate; it does not tie the certificate CN to the connecting
  role. That mapping needs `auth_type = cert`, and this deployment uses
  `scram-sha-256`. The per-app certificate is a strong outer gate, not an
  identity binding.
- The datastore host is an SSM managed node, so it is a Run Command target and
  Run Command runs as root. `ssm:SendCommand` is denied to the developer group
  for that reason; keep it that way.

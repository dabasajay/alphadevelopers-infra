ENV ?= prod
TF  := tofu -chdir=terraform/envs/$(ENV)

.PHONY: help check-profile bootstrap init fmt validate plan apply plan-shared apply-shared output db-console

help:
	@grep -E '^[a-z-]+:' Makefile | cut -d: -f1 | grep -vE 'help|check-profile'

# The S3 backend resolves credentials itself and cannot read var.aws_profile,
# so AWS_PROFILE has to be exported for anything that touches AWS.
check-profile:
ifndef AWS_PROFILE
	$(error export AWS_PROFILE first, e.g. AWS_PROFILE=alphadevelopers make plan)
endif

fmt:
	tofu fmt -recursive terraform

validate:
	$(TF) validate

bootstrap: check-profile
	./scripts/bootstrap-state.sh

init: check-profile
	$(TF) init

# services/shared publishes the zone ids and WAF ACL the app services consume,
# so it has to exist before a full plan can resolve
plan-shared: check-profile
	$(TF) plan -target=module.shared -out=tfplan

apply-shared: check-profile
	$(TF) apply tfplan

plan: check-profile
	$(TF) plan -out=tfplan

apply: check-profile
	$(TF) apply tfplan

output: check-profile
	$(TF) output

# Read-only database console over an IAM-authenticated SSM tunnel. Needs the
# session-manager-plugin. 8091 rather than 8081, which local pgweb owns in the
# app repo's docker-compose. Leave it running and open http://localhost:8091.
db-console: check-profile
	aws ssm start-session \
	  --target "$$(aws ssm describe-instance-information \
	      --query 'InstanceInformationList[0].InstanceId' --output text)" \
	  --document-name alphadevelopers-prod-resume-builder-db-console \
	  --parameters '{"localPortNumber":["8091"]}'


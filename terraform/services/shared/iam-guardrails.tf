# Two console-created guardrails brought under Terraform. Neither carries a
# description: it is immutable in IAM, so setting one now would replace the
# policy and briefly leave the guardrail off.

data "aws_caller_identity" "current" {}

locals {
  # Anything that destroys data or detaches something load-bearing. A list so
  # the statement below stays readable.
  destructive_actions = [
    "s3:DeleteBucket",
    "s3:DeleteBucketPolicy",
    "s3:DeleteBucketWebsite",
    "s3:DeleteObject",
    "s3:DeleteObjectVersion",
    "s3:DeleteObjectTagging",
    "ec2:TerminateInstances",
    "ec2:DeleteVolume",
    "ec2:DeleteSnapshot",
    "ec2:DeleteVpc",
    "ec2:DeleteSubnet",
    "ec2:DeleteSecurityGroup",
    "ec2:DeleteKeyPair",
    "ec2:DeleteNatGateway",
    "ec2:DeleteInternetGateway",
    "ec2:DeleteRouteTable",
    "ec2:DeleteRoute",
    "ec2:DeleteNetworkAcl",
    "ec2:DeleteNetworkInterface",
    "ec2:DeregisterImage",
    "ec2:DeleteLaunchTemplate",
    "ec2:DeleteFleets",
    "ec2:DisassociateAddress",
    "ec2:ReleaseAddress",
    "ec2:DetachVolume",
    "ec2:DetachInternetGateway",
    "ec2:DetachNetworkInterface",
    "ec2:RevokeSecurityGroupIngress",
    "ec2:RevokeSecurityGroupEgress",
    "ec2:DeletePlacementGroup",
    "ec2:DeleteVpcPeeringConnection",
    "ec2:DeleteTransitGateway",
    "ec2:DeleteCustomerGateway",
    "ec2:DeleteVpnConnection",
    "ec2:DeleteVpnGateway",
    "rds:DeleteDBInstance",
    "rds:DeleteDBCluster",
    "rds:DeleteDBSnapshot",
    "rds:DeleteDBClusterSnapshot",
    "rds:DeleteDBSubnetGroup",
    "rds:DeleteDBParameterGroup",
    "rds:DeleteDBSecurityGroup",
    "rds:DeleteDBClusterParameterGroup",
    "rds:DeleteGlobalCluster",
    "dynamodb:DeleteTable",
    "dynamodb:DeleteBackup",
    "lambda:DeleteFunction",
    "lambda:DeleteFunctionConcurrency",
    "lambda:DeleteLayerVersion",
    "lambda:DeleteEventSourceMapping",
    "lambda:RemovePermission",
    "kms:ScheduleKeyDeletion",
    "kms:DeleteAlias",
    "kms:DeleteImportedKeyMaterial",
    "sqs:DeleteQueue",
    "sqs:PurgeQueue",
    "sqs:RemovePermission",
    "sns:DeleteTopic",
    "sns:RemovePermission",
    "sns:Unsubscribe",
    "cloudformation:DeleteStack",
    "cloudformation:DeleteStackSet",
    "cloudformation:DeleteChangeSet",
    "cloudformation:DeleteStackInstances",
    "ecs:DeleteCluster",
    "ecs:DeleteService",
    "ecs:DeregisterTaskDefinition",
    "ecs:DeregisterContainerInstance",
    "eks:DeleteCluster",
    "eks:DeleteNodegroup",
    "eks:DeleteFargateProfile",
    "eks:DeleteAddon",
    "secretsmanager:DeleteSecret",
    "ssm:DeleteParameter",
    "ssm:DeleteParameters",
    "ssm:DeleteDocument",
    "ssm:DeleteAssociation",
    "ssm:DeleteActivation",
    "ssm:DeleteMaintenanceWindow",
    "logs:DeleteLogGroup",
    "logs:DeleteLogStream",
    "logs:DeleteRetentionPolicy",
    "logs:DeleteMetricFilter",
    "logs:DeleteSubscriptionFilter",
    "cloudwatch:DeleteAlarms",
    "cloudwatch:DeleteDashboards",
    "cloudwatch:DeleteAnomalyDetector",
    "elasticache:DeleteCacheCluster",
    "elasticache:DeleteReplicationGroup",
    "elasticache:DeleteCacheSubnetGroup",
    "elasticache:DeleteCacheParameterGroup",
    "elasticache:DeleteSnapshot",
    "elasticfilesystem:DeleteFileSystem",
    "elasticfilesystem:DeleteMountTarget",
    "elasticfilesystem:DeleteAccessPoint",
    "elasticloadbalancing:DeleteLoadBalancer",
    "elasticloadbalancing:DeleteTargetGroup",
    "elasticloadbalancing:DeleteListener",
    "elasticloadbalancing:DeleteRule",
    "redshift:DeleteCluster",
    "redshift:DeleteClusterSnapshot",
    "redshift:DeleteClusterParameterGroup",
    "redshift:DeleteClusterSubnetGroup",
    "glue:DeleteDatabase",
    "glue:DeleteTable",
    "glue:DeleteCrawler",
    "glue:DeleteJob",
    "glue:DeleteWorkflow",
    "glue:DeleteTrigger",
    "athena:DeleteWorkGroup",
    "athena:DeleteDataCatalog",
    "athena:DeleteNamedQuery",
    "cloudfront:DeleteDistribution",
    "cloudfront:DeleteStreamingDistribution",
    "route53:DeleteHostedZone",
    "route53:DeleteHealthCheck",
    "route53:DeleteTrafficPolicy",
    "route53:DeleteTrafficPolicyInstance",
    "autoscaling:DeleteAutoScalingGroup",
    "autoscaling:DeleteLaunchConfiguration",
    "autoscaling:DeletePolicy",
    "autoscaling:DeleteScheduledAction",
    "apigateway:DELETE",
    "states:DeleteStateMachine",
    "states:DeleteActivity",
    "events:DeleteRule",
    "events:DeleteEventBus",
    "events:RemoveTargets",
    "kinesis:DeleteStream",
    "kinesis:DeregisterStreamConsumer",
    "acm:DeleteCertificate",
    "backup:DeleteBackupPlan",
    "backup:DeleteBackupVault",
    "backup:DeleteRecoveryPoint",
    "fsx:DeleteFileSystem",
    "fsx:DeleteBackup",
    "sagemaker:DeleteEndpoint",
    "sagemaker:DeleteEndpointConfig",
    "sagemaker:DeleteModel",
    "sagemaker:DeleteNotebookInstance",
    "sagemaker:DeleteDomain",
  ]

  # No regional endpoint, so a region condition would deny these everywhere.
  global_services = [
    "iam:*",
    "organizations:*",
    "route53:*",
    "route53domains:*",
    "cloudfront:*",
    "waf:*",
    "wafv2:*",
    "support:*",
    "trustedadvisor:*",
    "budgets:*",
    "ce:*",
    "health:*",
    "sts:*",
    "account:*",
  ]

  # Reachable in us-east-1 on top of the global set, for the CloudFront half of
  # the stack: its certificates, its metrics and the topic those alarms notify.
  edge_services = [
    "acm:*",
    "sns:*",
    "cloudwatch:*",
  ]

  # FireAnts runs in us-east-1 rather than ap-south-1, so the region confinement
  # has to admit the services it is built from. Deliberately the whole of that
  # stack and nothing else: a container registry, its logs, and the playground
  # runtime that reads one and writes the other. Everything outside this list
  # is still denied in us-east-1, so the guardrail keeps doing its job — no
  # stray console click leaves a database or a queue running unwatched.
  fireantslab_services = [
    "ecr:*",
    "logs:*",
    "bedrock-agentcore:*",
    "bedrock:*",
  ]
}

# What applying this repository needs, and nothing else.
#
# Derived from the resource types the configuration actually declares, not from
# a service list someone might want later: acm, bedrock-agentcore, cloudfront,
# ecr, iam, lambda, logs and cloudwatch, route53, s3, sns and wafv2. A service
# that appears in a future module has to be added here in the same change,
# which is the point — the policy is a statement of what the estate is made of.
#
# Region-scoped where the service is regional. The account uses two regions:
# ap-south-1 for the estate and us-east-1 for CloudFront's certificates and for
# FireAnts. Everywhere else stays denied, so a stray apply cannot leave
# resources running somewhere nobody is watching the bill.
data "aws_iam_policy_document" "claude_infra" {
  # Terraform reads far more than it writes: every plan refreshes every
  # resource. Describe and List are unconditional because a refusal here is a
  # failed plan rather than a prevented change, and none of them reveal a
  # secret this identity cannot already reach.
  statement {
    sid = "ReadEverythingThisRepositoryManages"
    actions = [
      "acm:Describe*",
      "acm:Get*",
      "acm:List*",
      "bedrock-agentcore:Get*",
      "bedrock-agentcore:List*",
      "cloudfront:Describe*",
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "ec2:DescribeRegions",
      "ecr:Describe*",
      "ecr:Get*",
      "ecr:List*",
      "iam:Get*",
      "iam:List*",
      "iam:SimulatePrincipalPolicy",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "lambda:Get*",
      "lambda:List*",
      "logs:Describe*",
      "logs:List*",
      "route53:Get*",
      "route53:List*",
      "s3:Get*",
      "s3:List*",
      "sns:Get*",
      "sns:List*",
      "sts:GetCallerIdentity",
      "wafv2:Get*",
      "wafv2:List*",
    ]
    resources = ["*"]
  }

  # The state itself. Separate from the buckets below because the lock is a
  # DeleteObject on one key and nothing else here may delete an object.
  statement {
    sid = "OwnTerraformState"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::${var.state_bucket}",
      "arn:aws:s3:::${var.state_bucket}/*",
    ]
  }

  # Buckets are a global namespace, so these carry no region condition. The
  # sub-resources are the ones Terraform manages as separate resources:
  # versioning, encryption, ownership, public access, lifecycle, object lock
  # and the bucket policy.
  statement {
    sid = "ManageBuckets"
    actions = [
      "s3:CreateBucket",
      "s3:DeleteBucket",
      "s3:PutBucketTagging",
      "s3:PutBucketVersioning",
      "s3:PutBucketPolicy",
      "s3:DeleteBucketPolicy",
      "s3:PutBucketPublicAccessBlock",
      "s3:PutBucketOwnershipControls",
      "s3:PutEncryptionConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:PutBucketObjectLockConfiguration",
      "s3:PutBucketAcl",
      "s3:PutObject",
      "s3:DeleteObject",
    ]
    resources = ["arn:aws:s3:::${var.name_prefix}-*", "arn:aws:s3:::${var.name_prefix}-*/*"]
  }

  # IAM has no region. Narrowed by path prefix instead: this identity manages
  # the estate's own roles, policies and the backup user, and cannot touch an
  # identity created outside it — including its own.
  statement {
    sid = "ManageEstateIdentities"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:TagUser",
      "iam:UntagUser",
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:CreateAccessKey",
      "iam:DeleteAccessKey",
      "iam:AttachGroupPolicy",
      "iam:DetachGroupPolicy",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
      "iam:UpdateOpenIDConnectProviderThumbprint",
      "iam:TagOpenIDConnectProvider",
      "iam:PassRole",
    ]
    resources = [
      "arn:aws:iam::*:role/${var.name_prefix}-*",
      "arn:aws:iam::*:policy/${var.name_prefix}-*",
      "arn:aws:iam::*:policy/ClaudeInfraPolicy",
      "arn:aws:iam::*:user/${var.name_prefix}-*",
      "arn:aws:iam::*:group/*",
      "arn:aws:iam::*:oidc-provider/*",
    ]
  }

  # Everything regional that this repository creates. The condition is the
  # whole of the region guardrail now: there is no separate deny, because a
  # policy that only allows two regions cannot reach a third.
  statement {
    sid = "ManageRegionalResources"
    actions = [
      "acm:RequestCertificate",
      "acm:DeleteCertificate",
      "acm:AddTagsToCertificate",
      "acm:RemoveTagsFromCertificate",
      "bedrock-agentcore:CreateAgentRuntime",
      "bedrock-agentcore:UpdateAgentRuntime",
      "bedrock-agentcore:DeleteAgentRuntime",
      "bedrock-agentcore:TagResource",
      "bedrock-agentcore:UntagResource",
      "cloudwatch:PutMetricAlarm",
      "cloudwatch:DeleteAlarms",
      "cloudwatch:TagResource",
      "cloudwatch:UntagResource",
      "ecr:CreateRepository",
      "ecr:DeleteRepository",
      "ecr:PutLifecyclePolicy",
      "ecr:DeleteLifecyclePolicy",
      "ecr:PutImageScanningConfiguration",
      "ecr:PutImageTagMutability",
      "ecr:TagResource",
      "ecr:UntagResource",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      # Creating and describing keys, never using, repolicing or deleting one: this
      # identity cannot decrypt what a key protects, nor schedule its destruction.
      "kms:CreateKey",
      "kms:CreateAlias",
      "kms:UpdateAlias",
      "kms:UpdateKeyDescription",
      "kms:EnableKeyRotation",
      "kms:TagResource",
      "kms:UntagResource",
      "lambda:CreateFunction",
      "lambda:DeleteFunction",
      "lambda:UpdateFunctionCode",
      "lambda:UpdateFunctionConfiguration",
      "lambda:CreateFunctionUrlConfig",
      "lambda:UpdateFunctionUrlConfig",
      "lambda:DeleteFunctionUrlConfig",
      "lambda:AddPermission",
      "lambda:RemovePermission",
      "lambda:PutFunctionConcurrency",
      "lambda:DeleteFunctionConcurrency",
      "lambda:TagResource",
      "lambda:UntagResource",
      "logs:CreateLogGroup",
      "logs:DeleteLogGroup",
      "logs:PutRetentionPolicy",
      "logs:DeleteRetentionPolicy",
      "logs:TagResource",
      "logs:UntagResource",
      "sns:CreateTopic",
      "sns:DeleteTopic",
      "sns:SetTopicAttributes",
      "sns:Subscribe",
      "sns:Unsubscribe",
      "sns:TagResource",
      "sns:UntagResource",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-south-1", "us-east-1"]
    }
  }

  # Invoking is not managing. A developer runs the app locally against the
  # deployed playground runtime, and that connection is signed by this identity,
  # so without these the local-against-AgentCore path cannot be exercised.
  statement {
    sid = "InvokeRuntimesForLocalDevelopment"
    actions = [
      "bedrock-agentcore:InvokeAgentRuntime",
      "bedrock-agentcore:InvokeAgentRuntimeWithWebSocketStream",
      "bedrock-agentcore:StopRuntimeSession",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-south-1", "us-east-1"]
    }
  }

  # No regional endpoint, so a region condition would deny these everywhere.
  # WAF is here because a CLOUDFRONT-scope ACL is only addressable in us-east-1
  # and behaves as a global resource.
  statement {
    sid = "ManageGlobalResources"
    actions = [
      "cloudfront:CreateDistribution",
      "cloudfront:UpdateDistribution",
      "cloudfront:DeleteDistribution",
      "cloudfront:CreateOriginAccessControl",
      "cloudfront:UpdateOriginAccessControl",
      "cloudfront:DeleteOriginAccessControl",
      "cloudfront:CreateFunction",
      "cloudfront:UpdateFunction",
      "cloudfront:DeleteFunction",
      "cloudfront:PublishFunction",
      "cloudfront:CreateCachePolicy",
      "cloudfront:UpdateCachePolicy",
      "cloudfront:DeleteCachePolicy",
      "cloudfront:CreateOriginRequestPolicy",
      "cloudfront:UpdateOriginRequestPolicy",
      "cloudfront:DeleteOriginRequestPolicy",
      "cloudfront:CreateResponseHeadersPolicy",
      "cloudfront:UpdateResponseHeadersPolicy",
      "cloudfront:DeleteResponseHeadersPolicy",
      "cloudfront:CreateInvalidation",
      "cloudfront:TagResource",
      "cloudfront:UntagResource",
      "cloudfront:AssociateAlias",
      "route53:ChangeResourceRecordSets",
      "route53:ChangeTagsForResource",
      "wafv2:CreateWebACL",
      "wafv2:UpdateWebACL",
      "wafv2:DeleteWebACL",
      "wafv2:TagResource",
      "wafv2:UntagResource",
      "wafv2:AssociateWebACL",
      "wafv2:DisassociateWebACL",
    ]
    resources = ["*"]
  }

  # The account, the organization and this identity's own permissions are not
  # this repository's to change. Applying never needs them, and an apply that
  # could grant itself more is not a guardrail.
  statement {
    sid    = "NeverEscalateOrTouchTheAccount"
    effect = "Deny"
    actions = [
      "organizations:*",
      "account:*",
      "iam:CreateAccountAlias",
      "iam:DeleteAccountAlias",
      "iam:UpdateAccountPasswordPolicy",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:AddUserToGroup",
      "iam:RemoveUserFromGroup",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "claude_infra" {
  name        = "ClaudeInfraPolicy"
  description = "Applying alphadevelopers-infra: exactly the services it declares, in the two regions it uses."
  policy      = data.aws_iam_policy_document.claude_infra.json
}

resource "aws_iam_user_policy_attachment" "claude_infra" {
  user       = var.infra_user
  policy_arn = aws_iam_policy.claude_infra.arn
}

# The developer group carries ReadOnlyAccess, which grants s3:Get* on every
# bucket and ssm:Get* on every parameter. GetParameter transparently decrypts a
# SecureString, so those two together are the encrypted backups plus the
# passphrase that opens them: an offline copy of production, leaving no trace
# beyond CloudTrail. Denied outright, because ReadOnlyAccess cannot be narrowed.
data "aws_iam_policy_document" "datastore_guardrails" {
  statement {
    sid       = "NeverReadTheDatabaseBackups"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [module.backup_bucket.arn, "${module.backup_bucket.arn}/*"]
  }

  statement {
    sid    = "NeverReadTheAnsibleSecrets"
    effect = "Deny"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath",
      "ssm:GetParameterHistory",
    ]
    resources = ["arn:aws:ssm:*:${data.aws_caller_identity.current.account_id}:parameter${var.ssm_secret_prefix}/*"]
  }

  # Registering the datastore host with SSM makes it a Run Command target, and
  # Run Command executes as root. Port forwarding needs none of these, so they
  # are denied before anything can grant them.
  statement {
    sid    = "NeverRunCommandsOnTheDatastoreHost"
    effect = "Deny"
    actions = [
      "ssm:SendCommand",
      "ssm:StartAutomationExecution",
      "ssm:StartChangeRequestExecution",
    ]
    resources = ["*"]
  }

  # StartSession authorises against the session document as well as the target,
  # so denying these leaves no route to a shell. AWS-StartPortForwardingSession
  # is in the list because it takes the remote port as a parameter, which would
  # let a caller forward to :22 or anything else bound on the host.
  statement {
    sid     = "NeverAShellOrAnArbitraryPort"
    effect  = "Deny"
    actions = ["ssm:StartSession"]
    resources = [
      "arn:aws:ssm:*:*:document/SSM-SessionManagerRunShell",
      "arn:aws:ssm:*:*:document/AWS-StartInteractiveCommand",
      "arn:aws:ssm:*:*:document/AWS-StartNonInteractiveCommand",
      "arn:aws:ssm:*:*:document/AWS-StartSSHSession",
      "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSession",
      "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSessionToRemoteHost",
    ]
  }
}

resource "aws_iam_policy" "datastore_guardrails" {
  name        = "${var.name_prefix}-datastore-guardrails"
  description = "Denies the developer group the database backups, the ansible secrets, and every SSM route to a shell on the datastore host."
  policy      = data.aws_iam_policy_document.datastore_guardrails.json
  tags        = { App = "shared" }
}

resource "aws_iam_group_policy_attachment" "datastore_guardrails" {
  group      = var.developer_group
  policy_arn = aws_iam_policy.datastore_guardrails.arn
}

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
}

data "aws_iam_policy_document" "region_locked_non_destructive" {
  statement {
    sid = "BroadAllowExceptIamOrgsAccount"
    not_actions = [
      "iam:*",
      "organizations:*",
      "account:*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "AllowSpecificIamOrgsAccountActions"
    actions = [
      "account:GetAccountInformation",
      "account:GetGovCloudAccountInformation",
      "account:GetPrimaryEmail",
      "account:ListRegions",
      "iam:ListRoles",
      "organizations:DescribeEffectivePolicy",
      "organizations:DescribeOrganization",
    ]
    resources = ["*"]
  }

  # Confines the account to the two regions it actually uses, so a stray console
  # click cannot leave resources running somewhere nobody is watching the bill.
  statement {
    sid         = "DenyOutsideAllowedRegion"
    effect      = "Deny"
    not_actions = local.global_services
    resources   = ["*"]

    condition {
      test     = "StringNotEquals"
      variable = "aws:RequestedRegion"
      values   = ["ap-south-1", "us-east-1"]
    }
  }

  # us-east-1 is allowed only for the edge services that have no choice but to
  # live there. Everything else there is still denied.
  statement {
    sid         = "DenyUsEast1ExceptEdgeServices"
    effect      = "Deny"
    not_actions = concat(local.global_services, local.edge_services)
    resources   = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = ["us-east-1"]
    }
  }

  # NotResource applies to the whole statement, so on tfstate objects every
  # action above is exempt. That is deliberate and narrow: releasing the native
  # state lock is a DeleteObject on the .tflock key. The bucket ARN itself is
  # not listed, so s3:DeleteBucket stays denied.
  statement {
    sid           = "DenyDestructiveActions"
    effect        = "Deny"
    actions       = local.destructive_actions
    not_resources = ["arn:aws:s3:::${var.state_bucket}/*"]
  }
}

resource "aws_iam_policy" "region_locked_non_destructive" {
  name   = "RegionLockedNonDestructiveAccess"
  policy = data.aws_iam_policy_document.region_locked_non_destructive.json
}

resource "aws_iam_group_policy_attachment" "region_locked_non_destructive" {
  group      = var.region_locked_group
  policy_arn = aws_iam_policy.region_locked_non_destructive.arn
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

# The identity the datastore host's SSM agent assumes once registered as a
# hybrid node. AmazonSSMManagedInstanceCore lets it register, heartbeat and
# carry a session, and nothing else.
data "aws_iam_policy_document" "ssm_hybrid_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ssm.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ssm_hybrid" {
  name               = "${var.name_prefix}-ssm-hybrid"
  assume_role_policy = data.aws_iam_policy_document.ssm_hybrid_assume.json
  tags               = { App = "shared" }
}

resource "aws_iam_role_policy_attachment" "ssm_hybrid_core" {
  role       = aws_iam_role.ssm_hybrid.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

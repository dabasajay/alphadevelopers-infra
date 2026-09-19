# A role assumed by an external workload through OIDC, so nothing has to hold an
# AWS key. `github-oidc-role` is the GitHub-shaped wrapper around the same idea;
# this one takes the issuer and its claims directly, for the providers that name
# them differently.
data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Every claim is an equality test. A role with no claims would be assumable
    # by anything the provider vouches for, so an empty map is rejected.
    dynamic "condition" {
      for_each = var.claims

      content {
        test     = "StringEquals"
        variable = "${var.issuer_host}:${condition.key}"
        values   = [condition.value]
      }
    }
  }
}

resource "aws_iam_role" "this" {
  name               = var.name
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags

  lifecycle {
    precondition {
      condition     = length(var.claims) > 0
      error_message = "claims must narrow the role to one workload; an unconditioned federated role is assumable by anything the provider issues for."
    }
  }
}

resource "aws_iam_role_policy" "this" {
  name   = var.policy_name
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

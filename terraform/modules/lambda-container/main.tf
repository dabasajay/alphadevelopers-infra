data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name               = "${var.name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "logs" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "extra" {
  name   = "${var.name}-policy"
  role   = aws_iam_role.this.id
  policy = var.policy_json
}

# Created explicitly so retention is set. Lambda's implicit group never expires.
resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_lambda_function" "this" {
  function_name = var.name
  role          = aws_iam_role.this.arn
  package_type  = "Image"
  image_uri     = var.image_uri
  # x86_64 avoids QEMU cross-builds on GitHub-hosted runners; the Graviton
  # discount is a few cents a month here.
  architectures = ["x86_64"]
  memory_size   = var.memory_mb
  timeout       = var.timeout
  tags          = var.tags

  reserved_concurrent_executions = var.reserved_concurrency

  # CI owns the deployed image and the console owns the environment. Neither is
  # declared here, and ignore_changes stops Terraform reconciling either away.
  lifecycle {
    ignore_changes = [image_uri, environment]
  }

  depends_on = [
    aws_iam_role_policy_attachment.logs,
    aws_cloudwatch_log_group.this,
  ]
}

resource "aws_lambda_function_url" "this" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "AWS_IAM"
}

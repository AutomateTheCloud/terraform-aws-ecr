resource "aws_ecr_repository_policy" "this" {
  policy     = data.aws_iam_policy_document.ecr_repository_policy.json
  repository = aws_ecr_repository.this.name
  provider   = aws.this
}

data "aws_iam_policy_document" "ecr_repository_policy" {
  statement {
    sid    = "ReadonlyAccess"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = concat([local.aws.account.id], var.accounts_read_access)
    }
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:DescribeImages",
      "ecr:DescribeImageScanFindings",
      "ecr:DescribeRepositories",
      "ecr:GetAuthorizationToken",
      "ecr:GetDownloadUrlForLayer",
      "ecr:GetRepositoryPolicy",
      "ecr:ListImages",
    ]
  }
  statement {
    sid    = "LambdaECRImageRetrievalPolicy"
    effect = "Allow"
    principals {
      type = "Service"
      identifiers = [
        "lambda.amazonaws.com"
      ]
    }
    actions = [
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
  }
  dynamic "statement" {
    iterator = aws_organization
    for_each = try(var.organization_read_access, [])
    content {
      effect = "Allow"
      principals {
        type        = "*"
        identifiers = ["*"]
      }
      actions = [
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:DescribeImageScanFindings",
        "ecr:DescribeRepositories",
        "ecr:GetAuthorizationToken",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:ListImages",
      ]
      condition {
        test     = "StringLike"
        variable = "aws:PrincipalOrgID"
        values   = [aws_organization.value]
      }
    }
  }

  provider = aws.this
}

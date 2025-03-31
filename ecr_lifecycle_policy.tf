resource "aws_ecr_lifecycle_policy" "name" {
  count      = (length(var.lifecycle_rules) > 0 ? 1 : 0)
  repository = aws_ecr_repository.this.name
  policy = templatefile("${path.module}/files/ecr_lifecycle_policy.json.tmpl", {
    lifecycle_rules = jsonencode(var.lifecycle_rules)
  })
  provider = aws.this
}

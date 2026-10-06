# Copyright 2026 Automate the Cloud Inc.
# SPDX-License-Identifier: Apache-2.0

variable "details" {
  description = <<-EOT
    Names and tags shared by every resource in the module. `scope`, `purpose` and `environment` become the `Scope`, `Purpose` and `Environment` tags, and are converted to abbreviations that other modules can use in resource names (see the `metadata` output). [The `details` input](https://github.com/AutomateTheCloud/terraform-aws-ecr#the-details-input) explains why it is required.

    - `scope` - (Required) What the resource belongs to, such as an organization or project: `Automate the Cloud`.
    - `purpose` - (Required) What the resource is for: `Web Site`.
    - `environment` - (Required) The environment: `Production`.
    - `scope_abbr`, `purpose_abbr`, `environment_abbr` - (Optional) Abbreviations to use instead of the generated ones, which are lowercase with words joined by underscores (`Web Site` becomes `web_site`).
    - `additional_tags` - (Optional) More tags for every resource, such as `{ CostCenter = "1234" }`.
  EOT
  type = object({
    scope            = string
    scope_abbr       = optional(string)
    purpose          = string
    purpose_abbr     = optional(string)
    environment      = string
    environment_abbr = optional(string)
    additional_tags  = optional(map(string), {})
  })
  nullable = false

  validation {
    condition     = trimspace(var.details.scope) != ""
    error_message = "Scope not specified."
  }

  validation {
    condition     = trimspace(var.details.purpose) != ""
    error_message = "Purpose not specified."
  }

  validation {
    condition     = trimspace(var.details.environment) != ""
    error_message = "Environment not specified."
  }
}

variable "enable_immutable_tags" {
  description = <<-EOT
    Make image tags immutable, so a pushed tag such as `v1.2.0` can never be overwritten by a different image. Set to `false` to allow tags such as `latest` to be moved to newer images.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

variable "force_delete" {
  description = <<-EOT
    Delete every image in the repository when it is destroyed. Without it, Terraform cannot destroy a repository that still holds images. Deleted images cannot be recovered.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable "image_name" {
  description = <<-EOT
    The name of the repository, after the optional `namespace`: `app` gives the repository `app`, or `my-team/app` with `namespace = "my-team"`. Lowercase letters and numbers, with single periods, underscores or hyphens between them. Changing it, or `namespace`, replaces the repository and deletes every image in it.
  EOT
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*$", var.image_name))
    error_message = "image_name must be lowercase letters and numbers, with single periods, underscores or hyphens between them, and no slashes (put a prefix in namespace)."
  }

  validation {
    condition     = length(var.namespace == "" ? var.image_name : "${var.namespace}/${var.image_name}") >= 2 && length(var.namespace == "" ? var.image_name : "${var.namespace}/${var.image_name}") <= 256
    error_message = "The repository name, namespace/image_name, must be 2 to 256 characters."
  }
}

variable "lifecycle_rules" {
  description = <<-EOT
    Lifecycle rules, which delete old images automatically, for example untagged images or all but the newest 100. An empty list, the default, creates no lifecycle policy and keeps every image. ECR applies the rules in order of `priority`, and an image is counted by only the first rule that matches it. See [Amazon ECR lifecycle policies](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html).

    Each rule takes:

    - `priority` - (Required) A unique whole number, 1 or more. Lower numbers are applied first. A rule with `tag_status = "any"` must have the highest number.
    - `description` - (Optional) What the rule is for.
    - `selection` - (Required) Which images the rule deletes:

      - `tag_status` - (Required) `untagged`, `tagged` or `any`.
      - `tag_prefix_list` - (Optional) For `tagged` only: images with a tag starting with one of these, such as `["v"]`.
      - `tag_pattern_list` - (Optional) For `tagged` only: images with a tag matching one of these patterns, where `*` matches any characters, such as `["*-rc*"]`. A `tagged` rule needs exactly one of `tag_prefix_list` or `tag_pattern_list`.
      - `count_type` - (Required) `imageCountMoreThan`, to keep only the newest `count_number` images, or `sinceImagePushed`, to delete images older than `count_number` days.
      - `count_unit` - (Optional) `days`. Required with `sinceImagePushed`, and not allowed with `imageCountMoreThan`.
      - `count_number` - (Required) A whole number, 1 or more.

    Matching images are deleted (the `expire` action). Deleted images cannot be recovered.
  EOT
  type = list(object({
    priority    = number
    description = optional(string)
    selection = object({
      tag_status       = string
      tag_prefix_list  = optional(list(string))
      tag_pattern_list = optional(list(string))
      count_type       = string
      count_unit       = optional(string)
      count_number     = number
    })
  }))
  default  = []
  nullable = false

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : r.priority >= 1 && floor(r.priority) == r.priority])
    error_message = "lifecycle_rules: each priority must be a whole number, 1 or more."
  }

  validation {
    condition     = length(distinct([for r in var.lifecycle_rules : r.priority])) == length(var.lifecycle_rules)
    error_message = "lifecycle_rules: each priority must be unique."
  }

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : contains(["untagged", "tagged", "any"], r.selection.tag_status)])
    error_message = "lifecycle_rules: selection.tag_status must be \"untagged\", \"tagged\" or \"any\"."
  }

  validation {
    condition = alltrue([for r in var.lifecycle_rules : (
      r.selection.tag_status == "tagged"
      ? (try(length(r.selection.tag_prefix_list), 0) > 0) != (try(length(r.selection.tag_pattern_list), 0) > 0)
      : r.selection.tag_prefix_list == null && r.selection.tag_pattern_list == null
    )])
    error_message = "lifecycle_rules: a rule with tag_status = \"tagged\" needs exactly one of selection.tag_prefix_list or selection.tag_pattern_list, and other rules can have neither."
  }

  validation {
    condition = alltrue([for r in var.lifecycle_rules : (
      (r.selection.count_type == "imageCountMoreThan" && r.selection.count_unit == null) ||
      (r.selection.count_type == "sinceImagePushed" && r.selection.count_unit == "days")
    )])
    error_message = "lifecycle_rules: selection.count_type must be \"imageCountMoreThan\" (with no count_unit) or \"sinceImagePushed\" (with count_unit = \"days\")."
  }

  validation {
    condition     = alltrue([for r in var.lifecycle_rules : r.selection.count_number >= 1 && floor(r.selection.count_number) == r.selection.count_number])
    error_message = "lifecycle_rules: selection.count_number must be a whole number, 1 or more."
  }

  validation {
    condition = alltrue([for r in var.lifecycle_rules : (
      r.selection.tag_status != "any" || r.priority == max([for x in var.lifecycle_rules : x.priority]...)
    )])
    error_message = "lifecycle_rules: a rule with tag_status = \"any\" must have the highest priority number, so it is applied last."
  }
}

variable "namespace" {
  description = <<-EOT
    A prefix for the repository name, such as `my-team` or `my-org/my-team`, which groups repositories. The repository is named `<namespace>/<image_name>`. Empty, the default, means no prefix.
  EOT
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.namespace == "" || can(regex("^[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)*$", var.namespace))
    error_message = "namespace must be lowercase letters and numbers, with single periods, underscores or hyphens between them, and single slashes between parts, with no slash at either end."
  }
}

variable "policy" {
  description = <<-EOT
    The repository policy, which lets other AWS accounts and services use the repository. A policy is created only when an option below grants access; by default there is none, and only the repository's own account, through its IAM policies, can use it.

    - `aws_account_read_access` - (Optional) 12-digit AWS account IDs that may pull and list images. Each account still needs an IAM policy for its users and roles, including `ecr:GetAuthorizationToken`.
    - `aws_organization_read_access` - (Optional) The same, for every account in an AWS Organization, by organization ID (`o-xxxxxxxxxx`).
    - `source_policy_documents` - (Optional) JSON policy documents whose statements are added to the policy, for anything the options above do not cover, such as letting AWS Lambda pull images or another account push them. Statement IDs (`Sid`) must be unique across the whole policy. See the [Lambda example](https://github.com/AutomateTheCloud/terraform-aws-ecr/tree/main/examples/lambda).
  EOT
  type = object({
    aws_account_read_access      = optional(list(string), [])
    aws_organization_read_access = optional(list(string), [])
    source_policy_documents      = optional(list(string), [])
  })
  default  = {}
  nullable = false

  validation {
    condition     = alltrue([for doc in var.policy.source_policy_documents : can(jsondecode(doc).Statement[0])])
    error_message = "Each of policy.source_policy_documents must be a JSON policy document with a non-empty Statement list."
  }

  validation {
    condition     = alltrue([for id in var.policy.aws_account_read_access : can(regex("^[0-9]{12}$", id))])
    error_message = "policy.aws_account_read_access must contain 12-digit AWS account IDs."
  }

  validation {
    condition     = alltrue([for id in var.policy.aws_organization_read_access : can(regex("^o-[a-z0-9]{10,32}$", id))])
    error_message = "policy.aws_organization_read_access must contain AWS Organization IDs (o-xxxxxxxxxx)."
  }
}

variable "region" {
  description = <<-EOT
    The AWS Region to create the repository and its policies in, such as `us-west-2`. Defaults to the Region of the AWS provider passed to the module.
  EOT
  type        = string
  default     = null
}

variable "scan_on_push" {
  description = <<-EOT
    Scan each image for known software vulnerabilities when it is pushed (ECR basic scanning, at no extra cost). Findings are shown in the ECR console and by `aws ecr describe-image-scan-findings`. If the registry has its own scanning configuration, such as Amazon Inspector enhanced scanning, that configuration applies instead.
  EOT
  type        = bool
  default     = true
  nullable    = false
}

# AWS - Elastic Container Registry - Terraform Module
Terraform module to create an Elastic Container Registry (AutomateTheCloud model)

***

## Usage
```hcl
module "ecr" {
  source    = "../"
  providers = { aws.this = aws.example }

  details = {
    scope       = "Demo"
    purpose     = "ECR"
    environment = "prd"
    additional_tags = {
      "Project"   = "Project Name"
      "ProjectID" = "123456789"
      "Contact"   = "David Singer - david.singer@example.com"
    }
  }

  namespace             = "organization"
  image_name            = "demo-image"
  enable_immutable_tags = true
  enable_scan           = true
  lifecycle_rules = [
    {
      rulePriority = 1
      description  = "Remove untagged images"
      selection = {
        tagStatus   = "untagged"
        countType   = "imageCountMoreThan"
        countNumber = 1
      },
      action = {
        type = "expire"
      }
    },
    {
      rulePriority = 2,
      description  = "Rotate images when more than 300 stored"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 300
      },
      action = {
        type = "expire"
      }
    }
  ]
  accounts_read_access = [
    "012345678901"
  ]
  organization_read_access = [
    "o-123456"
  ]
}
```

***

## Inputs
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `accounts_read_access` | AWS Accounts to provide read access to repository | `list` | `[]` |
| `enable_immutable_tags` | Configure a repository to be immutable to prevent image tags from being overwritten | `bool` | `true` |
| `enable_scan` | Indicates whether images are scanned after being pushed to the repository | `string` | `true` |
| `force_delete` | If true, will delete the repository even if it contains images | `bool` | `false` |
| `image_name` | Image Name | `string` | |
| `lifecycle_rules` | Lifecycle Rules | `any` | ([see below](#lifecycle-rules))|
| `namespace` | Namespace (optional) | `string` | |
| `organization_read_access` | AWS Organizations to provide read access to repository | `list` | `[]` |

## Inputs (Details)
| Name | Description | Type | Default |
|------|-------------|:----:|:-------:|
| `details.scope` | (Required) Scope Name - What does this object belong to? (Organization Name, Project, etc) | `string` | |
| `details.scope_abbr` | (Optional) Scope [Abbreviation](#abbreviations) Override | `string` | |
| `details.purpose` | (Required) Purpose Name - What is the purpose or function of this object, or what does this object server? | `string` | |
| `details.purpose_abbr` | (Optional) Purpose [Abbreviation](#abbreviations) Override | `string` | |
| `details.environment` | (Required) Environment Name | `string` | |
| `details.environment_abbr` | (Optional) Environment [Abbreviation](#abbreviations) Override | `string` | |
| `details.additional_tags` | (Optional) [Additional Tags](#additional-tags) for resources | `map` | `[]` |

***

## Outputs
All outputs from this module are mapped to a single output named `metadata` to make it easier to capture all of the relevant metadata that would be useful when referenced by other stacks (requires only a single output reference in your code, instead of dozens!)

| Name | Description |
|:-----|:------------|
| `details.scope.name` | Scope name |
| `details.scope.abbr` | Scope abbreviation |
| `details.scope.machine` | Scope machine-friendly abbreviation |
| `details.purpose.name` | Purpose name |
| `details.purpose.abbr` | Purpose abbreviation |
| `details.purpose.machine` | Purpose machine-friendly abbreviation |
| `details.environment.name` | Environment name |
| `details.environment.abbr` | Environment abbreviation |
| `details.environment.machine` | Environment machine-friendly abbreviation |
| `details.tags` | Map of tags applied to all resources |
| `aws.account.id` | AWS Account ID |
| `aws.region.name` | AWS Region name, example: `us-east-1` |
| `aws.region.abbr` | AWS Region four letter abbreviation, example: `use1` |
| `aws.region.description` | AWS Region description, example: `US East (N. Virginia)` |
| `ecr.name` | ECR - Repository |

***

## Notes

### Abbreviations
* When generating resource names, the module converts each identifier to a more 'machine-friendly' abbreviated format, removing all special characters, replacing spaces with underscores (_), and converting to lowercase. Example: 'Demo - Module' => 'demo_module'
* Not all resource names allow underscores. When those are encountered, the detail identifier will have the underscore removed (test_example => testexample) automatically. This machine-friendly abbreviation is referred to as 'machine' within the module.
* The abbreviations can be overridden by suppling the abbreviated names (ie: scope_abbr). This is useful when you have a long name and need the created resource names to be shorter. Some resources in AWS have shorter name constraints than others, or you may just prefer it shorter. NOTE: If specifying the Abbreviation, be sure to follow the convention of no spaces and no special characters (except for underscore), otherwise resoure creation may fail.

### Additional Tags
* You can specify additional tags for resources by adding to the `details.additional_tags` map.
```
additional_tags = {
  "Example"         = "Extra Tag"
  "Project"         = "Project Name"
  "CostCenter"      = "123456"
}
```

### Lifecycle Rules
- [Amazon ECR Lifecycle Policies Document](https://docs.aws.amazon.com/AmazonECR/latest/userguide/LifecyclePolicies.html#lifecycle_policy_syntax)
- Convert JSON Rule format to Terraform List
Default:
```
[
  {
    priority      = 1
    description   = "Remove untagged images"
    tag_status    = "untagged"
    count_type    = "imageCountMoreThan"
    count_number  = 1
    action        = "expire"
  }
]
```

Examples:
```
[
  {
    rulePriority = 1
    description  =  "Remove untagged images"
    selection = {
      tagStatus = "untagged"
      countType = "imageCountMoreThan"
      countNumber = 1
    },
    action = {
      type = "expire"
    }
  },
  {
    rulePriority = 10,
    description  =  "Keep Stable Images"
    selection = {
      tagStatus = "tagged"
      tagPrefixList = [ "v" ]
      countType = "imageCountMoreThan"
      countNumber = 9999
    },
    action = {
      type = "expire"
    }
  },
  {
    rulePriority = 20,
    description  =  "Cleanup Images - Devel"
    selection = {
      tagStatus = "tagged"
      tagPrefixList = [ "devel" ]
      countType   = "sinceImagePushed"
      countUnit   = "days"
      countNumber = 14
    },
    action = {
      type = "expire"
    }
  },
  {
    rulePriority = 21,
    description  =  "Cleanup Images - Release Candidates"
    selection = {
      tagStatus = "tagged"
      tagPrefixList = [ "rc" ]
      countType   = "sinceImagePushed"
      countUnit   = "days"
      countNumber = 14
    },
    action = {
      type = "expire"
    }
  }
]
```

***

## Terraform Versions
Terraform ~> 1.11.0 is supported.

## Provider Versions
| Name | Version |
|------|---------|
| aws | `~> 5.93` |

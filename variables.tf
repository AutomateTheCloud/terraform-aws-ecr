variable "accounts_read_access" {
  description = "AWS Accounts to provide read access to repository"
  type        = list(any)
  default     = []
}

variable "enable_immutable_tags" {
  description = "Configure a repository to be immutable to prevent image tags from being overwritten"
  type        = bool
  default     = true
}

variable "enable_scan" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "force_delete" {
  description = "If true, will delete the repository even if it contains images"
  type        = bool
  default     = false
}

variable "image_name" {
  description = "Image Name"
  type        = string
  default     = ""
}

variable "lifecycle_rules" {
  description = "Lifecycle Rules"
  type        = any
}

variable "namespace" {
  description = "Namespace (optional)"
  type        = string
  default     = ""
}

variable "organization_read_access" {
  description = "AWS Organizations to provide read access to repository"
  type        = list(any)
  default     = []
}
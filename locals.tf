locals {
  ecr = {
    repository_name = (var.namespace != "" ? "${var.namespace}/${var.image_name}" : var.image_name)
  }
}

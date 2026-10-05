# Complete repository

Most of the module's options in one private repository, named `example-team/example-app`:

- Immutable tags and scan on push.
- Lifecycle rules that delete untagged images after 7 days, keep the newest 50 release images (tags starting with `v`), delete release candidates (tags containing `-rc`) after 30 days, and keep at most 500 images in all.
- Read access for other AWS accounts and AWS Organizations, if you give their IDs. Without them, no repository policy is created.
- An abbreviation override and an extra tag in `details`.

## Run it

```shell
terraform init
terraform apply -var 'read_access_account_ids=["<another account ID>"]'
```

Every account you list must exist, or AWS rejects the policy. Remove the example with `terraform destroy` and the same `-var`. Destroying fails if the repository still holds images, so images are never deleted by accident.

<!-- BEGIN_TF_DOCS -->
### Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement_terraform) (>= 1.9)

- <a name="requirement_aws"></a> [aws](#requirement_aws) (~> 6.0)

### Optional Inputs

The following input variables are optional (have default values):

#### <a name="input_read_access_account_ids"></a> [read_access_account_ids](#input_read_access_account_ids)

Description: 12-digit IDs of other AWS accounts that may pull images. Empty for none.

Type: `list(string)`

Default: `[]`

#### <a name="input_read_access_organization_ids"></a> [read_access_organization_ids](#input_read_access_organization_ids)

Description: IDs of AWS Organizations (o-xxxxxxxxxx) whose accounts may pull images. Empty for none.

Type: `list(string)`

Default: `[]`

### Outputs

The following outputs are exported:

#### <a name="output_metadata"></a> [metadata](#output_metadata)

Description: Everything the module created
<!-- END_TF_DOCS -->

# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- An Amazon ECR repository with secure defaults: no access for other accounts or services, immutable tags, and scan on push.
- Lifecycle rules that delete untagged, old or surplus images, checked at plan time.
- A repository policy with read access for other AWS accounts and AWS Organizations, and your own statements through `policy.source_policy_documents`.
- `region`, to create the repository in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for a basic repository, a repository for AWS Lambda images, and most options together.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-ecr/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-ecr/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-ecr/releases/tag/v1.0.0

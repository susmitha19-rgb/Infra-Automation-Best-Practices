# Terraform governance

The Azure DevOps validation pipeline runs Checkov against `modules/` and
`environments/`. The blocking checks currently cover AWS instance metadata
service v2, encrypted EBS volumes, S3 server-side encryption, and Azure Storage
secure transfer. Expand the required Checkov checks as new module types and
controls are introduced; do not suppress a finding without a reviewed,
documented exception.

The pipeline also validates registry mappings and Terraform configuration.
These repository checks complement, but do not replace, cloud-account controls.
Configure the following in Azure DevOps and the cloud accounts:

- Reusable modules require a non-empty `environment` tag and
  `managed_by = "terraform"`; supply these tags through the root's
  configuration. Extend the tag contract with any organization-required
  ownership or cost-allocation fields.
- Require pull-request review and protect `main`; restrict tag creation and
  pipeline edits to approved maintainers.
- Use least-privilege Azure Resource Manager and AWS service connections,
  preferably workload identity federation or short-lived credentials.
- Restrict deployment identities to the selected root's resources and its
  backend. Do not grant broad subscription/account administrator access.
- Require the production approval stage before apply. Keep plan artifacts
  access-restricted because plans can contain sensitive values.
- Enable Azure Storage encryption, versioning/recovery and access logging for
  Azure state. Enable S3 encryption, versioning, access logging and lock-file
  permissions for AWS state. Restrict backend access and retention according
  to organizational requirements.
- Apply organization naming and tagging standards to resource inputs. Secrets
  belong in approved secret stores, never in Terraform source or example
  variable files.

Cloud-side RBAC, policy assignments, audit retention, state-store setup, and
Azure DevOps branch/environment protections are external configuration; this
repository documents the required controls but cannot enable them in your
tenant or cloud accounts.

# Reusable, multi-cloud Terraform

Reusable modules and deployable environment roots are separate:

- `modules/` contains independently reusable modules. Azure and AWS modules are separate implementations because each cloud has different resources and providers. The module interfaces (inputs/outputs) follow the same layer-oriented conventions.
- `live/` contains deployment roots, which compose pinned module releases and own backend configuration. Each cloud/environment/layer root has one independent remote state.

## Repository structure

```text
modules/
  network/
    azure/resource-group/
    azure/virtual-network/
    aws/vpc/
  compute/
    azure/linux-virtual-machine/
    aws/ec2-instance/
  application/
    azure/storage-account/
    aws/s3-bucket/
live/
  dev/
    azure/{network,compute,application}/
    aws/{network,compute,application}/
templates/terraform-pipeline.yml
azure-pipelines-module-release.yml
azure-pipelines-{azure,aws}[-{compute,application}].yml
```

Every module has `main.tf`, `variables.tf`, `outputs.tf`, and `version.tf`. The module `version.tf` declares a compatible Terraform version and required provider source/version. Modules do not configure providers or remote state; callers provide provider configuration. Each live root also has its own provider/backend configuration and `.terraform.lock.hcl`.

## Separate remote state for every layer

| Live root | Remote state key |
|---|---|
| `live/dev/azure/network` | `azure/dev/network.tfstate` |
| `live/dev/azure/compute` | `azure/dev/compute.tfstate` |
| `live/dev/azure/application` | `azure/dev/application.tfstate` |
| `live/dev/aws/network` | `aws/dev/network.tfstate` |
| `live/dev/aws/compute` | `aws/dev/compute.tfstate` |
| `live/dev/aws/application` | `aws/dev/application.tfstate` |

Azure uses the `azurerm` backend, storing each state as a blob in a private Azure Storage container. AWS uses the S3 backend, storing each state as a separate S3 object and using Terraform 1.10+ S3 lock files. Backend bucket/container and credentials are supplied to `terraform init` by the deployment pipelines; they are deliberately not committed in backend files.

Provision both remote backend stores independently from these workloads. The Azure service identity requires state-container data permissions; the AWS role requires state object and `.tflock` permissions. Grant access only to the states and resources each layer needs. Compute reads the network layer outputs through `terraform_remote_state`; Azure application reads the network layer's resource group and location. Deploy network first and destroy dependent layers first in reverse order. Separate states are independent and are not transactional.

Do not apply these new roots against an existing combined stack until its state has been backed up and deliberately migrated. Otherwise Terraform can attempt to recreate resources already present in the old state.

## Module versions and releases

`azure-pipelines-module-release.yml` validates every module on PR. After module changes merge to `main`, it creates immutable, module-specific annotated Git tags and publishes source bundles as a pipeline artifact. The first release is `v1.0.0`; later module changes increment that module's patch version. Example tag:

```text
terraform-network-azure-virtual-network-v1.0.1
```

Live roots consume exact Git tag versions in their `module.source` references, so a module change does not change an environment until its pinned `ref` is intentionally updated and reviewed. Release tags are read-only by policy: do not overwrite or delete them. The pipeline identity needs repository read and tag-create/push permissions.

Replace `REPLACE_ORG`, `REPLACE_PROJECT`, and `REPLACE_REPO` in the six live root `main.tf` files with your Azure DevOps organization, project, and repository. The layer pipelines persist checkout credentials so Terraform can fetch private modules from the same repo. Ensure the pipeline identity has repository read access.

Bootstrap by registering/running the module release pipeline first and waiting for the initial module tags. Then enable live pipelines. Update each live root's pinned tag when promoting a module release.

The pipeline artifact is a downloadable/archive copy of each versioned module. Terraform itself fetches the pinned tag from Git; the artifact is retained for release traceability. If you require deployment roots to install modules only from Azure Artifacts rather than Git, that needs a package-download/extract step in the deployment pipeline instead.

## Azure DevOps deployment pipelines

Register one pipeline per live root:

| Pipeline YAML | Root | Remote state key |
|---|---|---|
| `azure-pipelines-azure.yml` | `live/dev/azure/network` | `azure/dev/network.tfstate` |
| `azure-pipelines-azure-compute.yml` | `live/dev/azure/compute` | `azure/dev/compute.tfstate` |
| `azure-pipelines-azure-application.yml` | `live/dev/azure/application` | `azure/dev/application.tfstate` |
| `azure-pipelines-aws.yml` | `live/dev/aws/network` | `aws/dev/network.tfstate` |
| `azure-pipelines-aws-compute.yml` | `live/dev/aws/compute` | `aws/dev/compute.tfstate` |
| `azure-pipelines-aws-application.yml` | `live/dev/aws/application` | `aws/dev/application.tfstate` |

The pipelines share `templates/terraform-pipeline.yml`: PRs validate; main-branch builds plan and apply the exact saved plan behind an Azure DevOps Environment approval.

Before deployment:

1. Provision an Azure Storage account/private state container and an encrypted, versioned S3 state bucket.
2. Create least-privilege Azure Resource Manager and AWS service connections. Prefer workload federation/short-lived credentials.
3. Replace state-store and service-connection placeholders in the pipeline files. Keep backend settings consistent within each cloud. Compute and Azure application identities also require read access to network state.
4. Create protected Azure DevOps Environments: `terraform-azure-dev-{network,compute,application}` and `terraform-aws-dev-{network,compute,application}`.
5. Set unique non-secret values in each `terraform.tfvars.example`. Azure compute needs an SSH public key; AWS compute needs an AMI ID valid in the chosen region. Never put private keys or credentials into Terraform variables.
6. Restrict who can edit pipelines, use service connections, push release tags, and read saved plan artifacts. Plans may contain sensitive values.

The sample AWS subnet has no internet gateway/NAT, and instances have no public IP or inbound security-group rule. Add organization-approved private connectivity and management access before deploying workloads that require access.

## Local checks

Use Terraform 1.10.5 (the pipeline version). After replacing the Azure Repos placeholders and creating initial tags:

```sh
terraform fmt -check -recursive
terraform -chdir=live/dev/azure/network init -backend=false
terraform -chdir=live/dev/azure/network validate
terraform -chdir=live/dev/azure/compute init -backend=false
terraform -chdir=live/dev/azure/compute validate
terraform -chdir=live/dev/azure/application init -backend=false
terraform -chdir=live/dev/azure/application validate
terraform -chdir=live/dev/aws/network init -backend=false
terraform -chdir=live/dev/aws/network validate
terraform -chdir=live/dev/aws/compute init -backend=false
terraform -chdir=live/dev/aws/compute validate
terraform -chdir=live/dev/aws/application init -backend=false
terraform -chdir=live/dev/aws/application validate
```

Commit each live root's `.terraform.lock.hcl` to keep provider selections reproducible. Real deployments must use each root's configured remote backend, never local state.

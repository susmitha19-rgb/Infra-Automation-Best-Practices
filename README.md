# Enterprise multi-cloud Terraform platform

This repository is the infrastructure-as-code repository for a layer-based Azure and AWS platform. It provides reusable provider-specific modules, isolated environment roots, and Azure DevOps validation and deployment pipelines. Application source code and application build/release pipelines belong in separate application repositories; those repositories consume platform services but do not share Terraform state with this repository.

## Platform architecture

The canonical deployment layers are:

| Layer | Typical responsibility |
|---|---|
| `foundation` | Account/subscription baselines, identity prerequisites, policy, and state backends |
| `shared-services` | Shared DNS, logging, monitoring, and common platform services |
| `security` | Security controls, key management, and guardrails |
| `network` | VPC/VNet, subnets, routing, and private connectivity |
| `data` | Managed databases, queues, and data services |
| `compute` | Virtual machines and other compute infrastructure |
| `platform` | Container, runtime, and developer platform services |
| `integration` | Cross-platform and external-system integration |
| `operations` | Backup, observability, and operational tooling |

The `network` directory is the repository's existing name for the **Networking** layer. The older `application` roots in `dev` provision application-facing infrastructure (Azure Storage/AWS S3); they are retained for compatibility and are not an application source-code repository or a tenth canonical layer.

Each canonical layer has its own root for every environment and cloud:

```text
environments/
  {dev,sit,uat,prod}/
    {azure,aws}/
      {foundation,shared-services,security,network,data,compute,platform,integration,operations}/
```

Provider-specific implementations remain separate under `modules/<layer>/{azure,aws}/`. A root may compose only modules for its cloud. Add resources and modules only when that layer's ownership, inputs, outputs, and security requirements are defined. Newly scaffolded roots intentionally contain no managed resources; they validate and plan safely without implying that a layer's design is complete.

The intended promotion sequence is foundation, shared services, security, networking, data, compute, platform, integration, and operations. Actual dependencies must be declared through narrowly scoped remote-state outputs or other approved interfaces, not by sharing state. Deploy prerequisite layers first and destroy dependent layers first. Do not add a dependency merely because one layer is earlier in this sequence.

The currently implemented provider-specific modules are Azure resource group/virtual network, Linux virtual machine, and storage account modules, plus AWS VPC, EC2 instance, and S3 bucket modules. These are currently composed by the dev roots. The other canonical layer roots, and network/compute roots outside dev, are state/pipeline-ready scaffolds with no managed resources until their designs and modules are supplied.

## State and environment isolation

Every cloud/environment/layer root has a separate backend state. The object key follows `<cloud>/<environment>/<layer>.tfstate`, for example:

| Root | State key |
|---|---|
| `environments/dev/azure/network` | `azure/dev/network.tfstate` |
| `environments/sit/aws/security` | `aws/sit/security.tfstate` |
| `environments/uat/azure/data` | `azure/uat/data.tfstate` |
| `environments/prod/aws/operations` | `aws/prod/operations.tfstate` |

Azure roots use the `azurerm` backend with a private Storage container; AWS roots use S3 with Terraform 1.10+ S3 lock files. Backend names and credentials are supplied by Azure DevOps at initialization time, not stored in backend configuration. Provision and secure both state stores independently. Enable encryption, versioning/recovery, least-privilege access, and appropriate retention. The pipeline identity needs access only to the backend and resources required by its root.

An apply to one root changes only that root's state. It does not make changes to other layers transactional; a drift repair, refresh, plan, or apply remains scoped to the selected root. Back up and deliberately migrate any pre-existing combined state before using these roots against resources tracked by it.

## Modules and repository boundaries

- `modules/` contains reusable Terraform modules, with separate Azure and AWS implementations where resource APIs or providers differ.
- `environments/` contains deployment roots and backend configuration. Roots pin module Git tags and own their independent state.
- `azure-pipelines.yml` is the single infrastructure pipeline entry point. `templates/terraform-pipeline.yml` holds its reusable CI/CD stages.
- Application source and its build/deployment pipeline belong in a separate application repository. That pipeline consumes infrastructure interfaces (such as service endpoints or published outputs) and does not check out or modify this repository's Terraform state.

Modules declare Terraform/provider requirements but do not configure providers or remote state. Keep module interfaces stable and layer-oriented. Live roots use immutable, exact module tags; update a pin through a reviewed change rather than consuming a moving branch.

## Azure DevOps CI/CD

Register **one** Azure DevOps pipeline for `azure-pipelines.yml`. Pull requests and main-branch runs format-check and validate all reusable modules and all Terraform roots. On `main`, changed modules are versioned with immutable annotated Git tags; the first release is `v1.0.0`, and later changes increment that module's patch version. Example:

```text
terraform-network-azure-virtual-network-v1.0.1
```

On a main-branch run, the pipeline automatically plans and applies changed roots after validation. Defaults are both clouds, dev, and changed layers. Select Azure or AWS for one cloud, select an environment deliberately, and choose one of three scopes: `changed` deploys roots changed in the triggering commit, `layer` deploys the chosen layer, and `all` deploys every layer in dependency order. An `all` run can target one cloud or both clouds; the legacy application-infrastructure root is included in dev. Each root still uses its own state file, and the saved plan for each cloud/layer is the plan that gets applied. If a change is made for SIT, UAT, or production, run the pipeline with that environment selected; non-production applies automatically after validation. Multi-root applies are sequential, not transactional: if one root fails, earlier successful applies remain in place and later roots are not applied.

Non-production deployments proceed automatically after validation. A production run stops at the `ProductionApproval` manual-validation stage before apply. Only approve after reviewing the plan artifact. Do not configure additional manual approvals on non-production environments. Do not overwrite or delete module release tags. The pipeline identity needs repository read and tag-create/push permissions.

Before enabling deployments:

1. Provision the Azure Storage state container and encrypted, versioned S3 state bucket; configure recovery and lock-file permissions.
2. Create least-privilege Azure Resource Manager and AWS service connections. Prefer workload federation or short-lived credentials.
3. Configure the backend-store placeholders in `azure-pipelines.yml`, and select the appropriate service connection when queuing a deployment. Keep backend settings consistent and do not commit credentials.
4. Create Azure DevOps Environments named `terraform-<cloud>-<environment>` for audit/tracking. The pipeline's production approval is an explicit manual-validation stage; no separate manual approval is needed on non-production environments.
5. Replace the Azure Repos placeholders in existing live module sources with the correct organization, project, and repository before validating those roots.
6. Use non-secret example variable values. Never put credentials, private keys, or other secrets in Terraform files, variable files, or saved plan artifacts. Restrict access to plan artifacts because they can contain sensitive values.

This infrastructure pipeline does not deploy application code. The separate application repository owns its build and release lifecycle and deploys independently against the provisioned platform, so application releases do not trigger infrastructure state changes.

The legacy dev AWS sample has no internet gateway/NAT, and its instances have no public IP or inbound security-group rule. Add organization-approved private connectivity and management access before deploying workloads that require access.

## Extending a layer

1. Define the layer's resource ownership, module interface, data classification, dependency direction, and operational responsibilities.
2. Implement and validate provider-specific modules under `modules/<layer>/<cloud>/`; avoid cross-cloud conditionals in provider-specific resources.
3. Add module tests/validation and release a new immutable module tag.
4. Compose the pinned release in the corresponding `environments/<environment>/<cloud>/<layer>/main.tf`. Add only the variables and outputs needed by that layer.
5. Add explicit remote-state access only for documented upstream outputs. Keep credentials and backend settings outside source control.
6. Review the plan, approval policy, IAM/RBAC permissions, and state key before enabling apply. Choose the target environment deliberately. Dev, SIT, and UAT apply automatically after validation; production pauses for explicit manual approval.

## Local checks

Use Terraform 1.10.5, matching the pipelines. For example:

```sh
terraform fmt -check -recursive
terraform -chdir=environments/dev/azure/network init -backend=false
terraform -chdir=environments/dev/azure/network validate
terraform -chdir=environments/sit/aws/security init -backend=false
terraform -chdir=environments/sit/aws/security validate
```

Run `init -backend=false` and `validate` for every changed root and commit its `.terraform.lock.hcl`. Real deployments must use each root's configured remote backend, never local state.

# ServiceNow catalog to Terraform deployment workflow

## Purpose and status

This document describes a proposed self-service flow in which a requestor
submits an infrastructure request through a ServiceNow catalog item and the
approved request is executed by the existing Azure DevOps Terraform pipeline.

This is a workflow design, not an implemented integration. Today, the pipeline
does not call ServiceNow or generate a request-specific Terraform variable
file. It currently passes `terraform.tfvars.example` to Terraform. Implementing
this design will require a later change to the integration and pipeline code.

## Systems and responsibilities

| Component | Responsibility |
|---|---|
| ServiceNow catalog | Collect requestor, provider, environment, service, action, and approved service-specific configuration; validate required fields and route approvals. |
| Integration identity | Start or resume an Azure DevOps run for an approved request and provide a request reference, not cloud credentials. |
| Azure DevOps pipeline | Validate the request, resolve the service using the registry, create the Terraform plan, apply only when authorized, and publish status. |
| Service registry | Map supported services to provider-specific module paths, owning layers, environments, and declared prerequisite layers. |
| Terraform roots/modules | Validate inputs, create infrastructure, and store state independently for each provider/environment/layer. |
| ServiceNow request record | Remain the request and approval system of record; receive run status and links to permitted evidence. |

## Catalog request fields

The catalog item should collect fields from controlled choices wherever
possible:

| Request field | Example | Pipeline/registry use |
|---|---|---|
| Provider | `azure` or `aws` | Selects the provider implementation, service connection, and backend type. Avoid `both` for an individual service request unless the catalog explicitly supports a coordinated multi-provider request. |
| Environment | `dev`, `sit`, `uat`, or `prod` | Selects the Terraform root and independent state. |
| Service | `network`, `compute`, or `application-storage` | Resolved against `service-registry/services.json`; availability is checked for provider and environment. |
| Action | `plan` or `apply` | `plan` stops after publishing a plan; `apply` continues only under the approval rules below. |
| Request ID | ServiceNow request/sys_id | Correlation and idempotency key for the pipeline run and status updates. |
| Requestor and business justification | User identity and explanation | Audit and approval context; not Terraform input unless an explicitly reviewed variable requires it. |
| Service-specific settings | For example region, CIDRs, resource name, VM size | Mapped to an allow-listed schema of Terraform root variables for the selected service. |
| Cost center, owner, data classification | Organization-approved values | Used for required governance tags or policy checks where supported by the root/module. |

The catalog should show only fields applicable to the selected service and
provider. The field schema and allowed values should be versioned and reviewed;
do not accept arbitrary Terraform variable names, file paths, CLI arguments,
module sources, state keys, shell commands, or pipeline expressions from a
requestor.

Never request cloud passwords, access keys, private keys, or other credentials
as catalog variables. Authenticate the pipeline using approved Azure DevOps
service connections and short-lived credentials. Retrieve any necessary
application secret from an approved secret store at execution time, and avoid
logging or publishing it.

## End-to-end workflow

1. **Request submission**
   - The requestor opens the ServiceNow catalog item and selects provider,
     environment, service, and action.
   - ServiceNow presents the service-specific fields and performs basic
     required-field, format, and allowed-value checks.
   - The request is recorded with its request ID, requestor, justification,
     requested values, and initial status.

2. **Policy and approval**
   - ServiceNow routes the request according to environment, service,
     ownership, and organizational risk policy.
   - Production apply requests require the designated human approval before
     execution. Additional approvals can be required by organizational
     policy.
   - A plan-only request may follow a lighter approval path if policy allows.
     Approval in ServiceNow is distinct from Terraform validation and from
     reviewing the resulting plan.

3. **Start the Azure DevOps run**
   - After the required ServiceNow approval, the integration starts the
     existing infrastructure pipeline and passes the ServiceNow request ID
     and a correlation identifier.
   - Prefer passing a request reference and retrieving approved request data
     over placing a large or sensitive payload in pipeline parameters.
   - The integration uses a dedicated, least-privilege identity. Protect its
     credentials, constrain which pipeline it can run, and verify that the
     request is approved and belongs to the expected catalog item.

4. **Retrieve and validate the approved request**
   - The pipeline retrieves the approved request through an authenticated
     integration, or consumes an equivalently authenticated and integrity-
     protected payload.
   - It verifies request status, request identity, catalog item, allowed
     provider/environment/service/action combinations, and the request
     schema. It rejects missing, stale, unapproved, or malformed requests.
   - It resolves the service through the service registry and confirms that
     registered modules and the selected environment root exist. It also
     resolves only declared layer dependencies.
   - It records the request ID and a non-secret configuration fingerprint in
     pipeline logs or metadata for traceability. It must not log secrets or
     dump the full request body.

5. **Create Terraform input files**
   - The pipeline maps approved catalog fields to the Terraform variables
     declared by the selected environment root. The root then passes those
     values into module inputs in its Terraform configuration.
   - It writes a request-specific `.tfvars` file in a temporary workspace
     with restrictive permissions. Values must be serialized safely as
     Terraform data, not concatenated into executable shell code.
   - The pipeline verifies the generated variables against the selected
     root's approved variable schema and rejects unexpected inputs.
   - The generated file is never committed, uploaded as a pipeline artifact,
     or included in diagnostic logs. Clean it up after execution. Keep
     secrets out of Terraform inputs when possible; Terraform state and plan
     files may contain sensitive values even when output is marked sensitive.

6. **Validate and scan**
   - Run the existing formatting, registry, unit-test, Terraform validation,
     and Checkov stages.
   - Validate that the required backend, provider service connection, and
     environment are configured. The requestor does not select backend names,
     state keys, or credentials.
   - On failure, stop before planning/applying resources and report a
     sanitized error against the ServiceNow request.

7. **Plan**
   - Initialize the selected root's remote backend using pipeline-controlled
     settings. State remains isolated by provider, environment, and layer.
   - Run `terraform plan` using the request-specific variable file and save
     the plan securely.
   - Publish the plan as a restricted artifact. Do not attach raw `.tfvars`,
     secrets, or an unrestricted plan to the ServiceNow record. Provide
     authorized approvers with a secure way to review the plan.

8. **Apply decision**
   - For action `plan`, mark the request as planned and do not apply.
   - For action `apply`, apply the exact saved plan created from the approved
     request values. Do not silently regenerate a different plan after
     approval.
   - Production apply must satisfy the ServiceNow approval and the configured
     production approval gate in Azure DevOps. Define the authoritative
     approval and ensure the two systems cannot disagree or allow a bypass.
   - For multi-layer services, apply prerequisite layers before dependent
     layers in registry order. Each layer uses its own state; the overall
     operation is sequential and not transactional.

9. **Update ServiceNow and close out**
   - Send pipeline status, run ID/link, completion time, selected service and
     environment, and sanitized outcome back to the ServiceNow request.
   - On success, record approved outputs or resource references only when
     permitted by policy. Do not expose credentials or unrestricted Terraform
     outputs.
   - On failure, record the failed stage and a sanitized reason, preserve
     diagnostic/audit references, and route the request for remediation.
     Do not report success when the pipeline result is unknown.

## Input and execution mapping

The intended data path is:

```text
ServiceNow approved request
  -> authenticated request lookup
  -> schema and policy validation
  -> provider/environment/service/action resolution
  -> registry layer/module resolution
  -> temporary root-specific .tfvars file
  -> terraform plan
  -> authorized plan review
  -> apply the saved plan (apply requests only)
  -> update ServiceNow request status
```

The variable file supplies **root variables**, not module variables directly.
Terraform loads the generated values at the root; the root's `main.tf` passes
selected values to module input arguments. The ServiceNow-to-root mapping
should therefore be defined against each root's `variables.tf`, then checked
against the corresponding module interfaces.

Do not treat the ServiceNow request as a source of Terraform code. It supplies
validated configuration values only. Terraform source, module versions,
backend configuration, dependency declarations, and pipeline logic remain
reviewed repository content.

## Request lifecycle and failure handling

Recommended lifecycle statuses are:

```text
Submitted -> Awaiting Approval -> Approved -> Queued -> Validating
          -> Planned -> Awaiting Plan Approval -> Applying -> Completed
```

Alternative terminal or recovery statuses include `Rejected`, `Validation
Failed`, `Plan Failed`, `Apply Failed`, and `Cancelled`. Use the organization's
ServiceNow status vocabulary if it differs.

Use the ServiceNow request ID as an idempotency key. A retried integration
call should locate or resume the corresponding pipeline run instead of
starting duplicate applies. Before an apply retry, inspect the existing run
and Terraform state; never blindly repeat a partially completed multi-layer
deployment. A failure in a later layer does not roll back earlier successful
layers.

## Security and operational requirements

- Use TLS and authenticated, least-privilege identities for ServiceNow,
  Azure DevOps, secret-store, and cloud interactions.
- Restrict which approved catalog item and fields may trigger infrastructure
  deployment. Validate all request values again in the pipeline.
- Do not allow a requestor to choose arbitrary cloud credentials, service
  connections, backends, state keys, Git refs, module versions, or commands.
- Restrict access and retention for Terraform plans, logs, state, and
  ServiceNow request data. Treat saved plans and state as potentially
  sensitive.
- Preserve request ID, approver, pipeline run, repository revision, module
  versions, plan/apply result, and timestamps for audit.
- Configure timeout, cancellation, duplicate-request, stale-approval,
  pipeline-failure, and ServiceNow-unavailable handling. Fail closed if
  approval or request data cannot be verified.
- Keep account RBAC, Azure DevOps environment protections, branch controls,
  policy assignments, backend encryption/recovery, and audit retention
  configured in their respective systems.

## Current repository behavior versus this workflow

| Capability | Current behavior | Required for ServiceNow workflow |
|---|---|---|
| Request intake | Azure DevOps pipeline parameters | ServiceNow catalog and authenticated request integration |
| Request values | Pipeline uses `terraform.tfvars.example` | Generate a validated, temporary variable file from approved request fields |
| Service selection | Registry resolves registered service to layers | Check the request against the registry and a root-variable schema |
| Plan/apply | Pipeline supports `plan` and `apply`; production has a manual validation stage | Correlate approvals to the ServiceNow request and apply only its reviewed saved plan |
| Status | Azure DevOps run is the primary status surface | Send correlated, sanitized run status back to ServiceNow |
| Credentials | Azure/AWS service connections authenticate cloud operations | Retain service connections; separately secure the ServiceNow integration identity |

The integration, request-derived variable generation, idempotency handling,
and ServiceNow status updates are design requirements in this document; they
are not implemented by the current repository.

# Platform architecture

## Repository boundaries

This repository owns infrastructure modules, Terraform roots, and their
Azure DevOps lifecycle. Application source code and application build/release
pipelines stay in separate repositories. Application teams consume published
infrastructure interfaces; they do not share or mutate Terraform state here.

## Layering and state

The canonical deployment order is foundation, shared services, security,
network, data, compute, platform, integration, and operations. `network` is
the repository directory name for the networking layer. Each environment,
provider, and layer has its own Terraform root and remote state key:

```text
<provider>/<environment>/<layer>.tfstate
```

The service catalog maps a service to its layer and provider-specific module
paths. A service deployment selects that layer and its explicitly declared
prerequisite layers, then operates on each environment root and state in
catalog order; it does not use Terraform resource targeting or split a layer's
state. Environment-wide deployments operate on the layer roots in catalog
order. The existing `application` root is a dev-only compatibility layer.

Layer ordering is not itself a dependency declaration. Add explicit
dependencies only when a Terraform root consumes a documented upstream
interface, such as a remote-state output. Plan/apply operations remain
independent per state and multi-root operations are sequential, not
transactional.

## Service catalog

`service-registry/services.json` is the configuration source for deployment
order, declared layer dependencies, dev-only legacy layers, service
ownership, environment availability, and provider-specific module paths. Run:

```sh
python templates/service-registry.py validate
python -m unittest discover -s tests -v
```

The catalog deliberately registers only services with existing module
implementations. Add a catalog entry only after a provider module and an
environment root exist. Root module sources remain pinned to immutable
version tags; the catalog does not override those versions.

## Delivery and security

`azure-pipelines.yml` is the single Azure DevOps entry point and
`templates/terraform-pipeline.yml` contains reusable CI/CD stages. CI formats
and validates modules and roots, tests the service catalog, and runs the
blocking Checkov security checks described in `policies/README.md`. Main-branch
deployments create plans first. Select `plan` to stop after publishing the
plan; select `apply` to apply the saved plan, with production requiring
approval.

Configure state backends, service connections, Azure DevOps environments,
RBAC, branch protection, logging and retention in the target tenant/account.
See the root README and `policies/README.md` before enabling deployment.

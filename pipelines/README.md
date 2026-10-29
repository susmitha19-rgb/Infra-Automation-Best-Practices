# Azure DevOps pipelines

Register the repository-root `azure-pipelines.yml` as the single Azure DevOps
pipeline entry point. Its reusable CI/CD orchestration lives in
`templates/terraform-pipeline.yml`; keep provider-specific deployment behavior
in `templates/terraform-deploy.sh` and service selection in
`templates/service-registry.py`.

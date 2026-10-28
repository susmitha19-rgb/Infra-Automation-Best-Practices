#!/usr/bin/env bash
set -euo pipefail

: "${CLOUD:?CLOUD is required}"
: "${TARGET_ENVIRONMENT:?TARGET_ENVIRONMENT is required}"
: "${DEPLOYMENT_SCOPE:?DEPLOYMENT_SCOPE is required}"
: "${LAYER:?LAYER is required}"
: "${TFVARS_FILE:?TFVARS_FILE is required}"
: "${PLAN_ACTION:?PLAN_ACTION must be plan or apply}"
: "${PLAN_DIR:?PLAN_DIR is required}"

if [[ "$DEPLOYMENT_SCOPE" == "all" ]]; then
  layers=(foundation shared-services security network data compute platform integration operations)
  if [[ "$TARGET_ENVIRONMENT" == "dev" ]]; then
    layers+=(application)
  fi
elif [[ "$DEPLOYMENT_SCOPE" == "layer" ]]; then
  layers=("$LAYER")
elif [[ "$DEPLOYMENT_SCOPE" == "changed" ]]; then
  base="$(git rev-parse HEAD^ 2>/dev/null || true)"
  if [[ -n "$base" ]]; then
    changed_files="$(git diff --name-only "$base" HEAD -- "environments/$TARGET_ENVIRONMENT/$CLOUD/")"
  else
    changed_files="$(git ls-tree -r --name-only HEAD -- "environments/$TARGET_ENVIRONMENT/$CLOUD/")"
  fi
  changed_layers="$(
    printf '%s\n' "$changed_files" |
      awk -F/ -v environment="$TARGET_ENVIRONMENT" -v cloud="$CLOUD" \
        '$1 == "environments" && $2 == environment && $3 == cloud && NF >= 5 { print $4 }' |
      sort -u
  )
  layers=()
  for candidate in foundation shared-services security network data compute platform integration operations application; do
    if grep -Fxq "$candidate" <<< "$changed_layers"; then
      layers+=("$candidate")
    fi
  done
else
  echo "Unsupported deployment scope: $DEPLOYMENT_SCOPE" >&2
  exit 1
fi

if [[ "$PLAN_ACTION" != "plan" && "$PLAN_ACTION" != "apply" ]]; then
  echo "Unsupported plan action: $PLAN_ACTION" >&2
  exit 1
fi

mkdir -p "$PLAN_DIR"

if [[ -z "${layers[*]-}" ]]; then
  echo "No Terraform roots changed for $CLOUD/$TARGET_ENVIRONMENT; deployment is not needed."
  echo "##vso[task.setvariable variable=hasDeploymentChanges;isOutput=true]false"
  touch "$PLAN_DIR/no-changes.txt"
  exit 0
fi

echo "##vso[task.setvariable variable=hasDeploymentChanges;isOutput=true]true"

for layer in "${layers[@]}"; do
  root="environments/$TARGET_ENVIRONMENT/$CLOUD/$layer"
  if [[ ! -d "$root" ]]; then
    echo "Selected Terraform root does not exist: $root" >&2
    exit 1
  fi

  backend_key="$CLOUD/$TARGET_ENVIRONMENT/$layer.tfstate"
  plan_file="$PLAN_DIR/$CLOUD-$layer.tfplan"
  echo "$PLAN_ACTION $root (state: $backend_key)"

  case "$CLOUD" in
    azure)
      : "${AZURE_TFSTATE_RESOURCE_GROUP:?AZURE_TFSTATE_RESOURCE_GROUP is required}"
      : "${AZURE_TFSTATE_STORAGE_ACCOUNT:?AZURE_TFSTATE_STORAGE_ACCOUNT is required}"
      : "${AZURE_TFSTATE_CONTAINER:?AZURE_TFSTATE_CONTAINER is required}"
      terraform -chdir="$root" init -input=false \
        -backend-config="resource_group_name=$AZURE_TFSTATE_RESOURCE_GROUP" \
        -backend-config="storage_account_name=$AZURE_TFSTATE_STORAGE_ACCOUNT" \
        -backend-config="container_name=$AZURE_TFSTATE_CONTAINER" \
        -backend-config="key=$backend_key" \
        -backend-config="use_azuread_auth=true" \
        -backend-config="use_cli=true"
      ;;
    aws)
      : "${AWS_TFSTATE_BUCKET:?AWS_TFSTATE_BUCKET is required}"
      : "${AWS_TFSTATE_REGION:?AWS_TFSTATE_REGION is required}"
      terraform -chdir="$root" init -input=false \
        -backend-config="bucket=$AWS_TFSTATE_BUCKET" \
        -backend-config="key=$backend_key" \
        -backend-config="region=$AWS_TFSTATE_REGION" \
        -backend-config="use_lockfile=true"
      ;;
    *)
      echo "Unsupported cloud: $CLOUD" >&2
      exit 1
      ;;
  esac

  if [[ "$PLAN_ACTION" == "plan" ]]; then
    terraform -chdir="$root" plan -input=false -lock-timeout=5m \
      -var-file="$TFVARS_FILE" \
      -out="$plan_file"
  else
    if [[ ! -f "$plan_file" ]]; then
      echo "Saved plan is missing for $root: $plan_file" >&2
      exit 1
    fi
    terraform -chdir="$root" apply -input=false -lock-timeout=5m "$plan_file"
  fi
done

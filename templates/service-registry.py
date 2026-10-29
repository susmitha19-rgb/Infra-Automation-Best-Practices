#!/usr/bin/env python3
"""Validate and resolve the Terraform service registry."""

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REGISTRY_PATH = ROOT / "service-registry" / "services.json"
ENVIRONMENTS = {"dev", "sit", "uat", "prod"}
IDENTIFIER = re.compile(r"^[a-z][a-z0-9-]*$")


def load_registry():
    with REGISTRY_PATH.open(encoding="utf-8") as registry_file:
        return json.load(registry_file)


def validate_registry(registry):
    if not isinstance(registry, dict):
        return ["registry must be a JSON object"]

    errors = []
    if registry.get("schema_version") != 1:
        errors.append("schema_version must be 1")

    deployment_order = registry.get("deployment_order")
    if not isinstance(deployment_order, list) or not deployment_order:
        errors.append("deployment_order must be a non-empty list")
        deployment_order = []
    else:
        if any(not isinstance(layer, str) or not IDENTIFIER.fullmatch(layer) for layer in deployment_order):
            errors.append("deployment_order contains an invalid layer identifier")
        if len(deployment_order) != len(set(deployment_order)):
            errors.append("deployment_order contains duplicate layers")

    legacy_layers = registry.get("legacy_layers", {})
    valid_legacy_layers = {}
    if not isinstance(legacy_layers, dict):
        errors.append("legacy_layers must be an object")
        legacy_layers = {}
    for environment, layers in legacy_layers.items():
        if environment not in ENVIRONMENTS or not isinstance(layers, list):
            errors.append(f"invalid legacy layer entry for {environment!r}")
            continue
        if any(not isinstance(layer, str) or not IDENTIFIER.fullmatch(layer) for layer in layers):
            errors.append(f"invalid legacy layer for {environment!r}")
        elif len(layers) != len(set(layers)):
            errors.append(f"duplicate legacy layer for {environment!r}")
        else:
            valid_legacy_layers[environment] = layers

    layer_dependencies = registry.get("layer_dependencies")
    if not isinstance(layer_dependencies, dict):
        errors.append("layer_dependencies must be an object")
        layer_dependencies = {}
    known_layers = set(deployment_order)
    for layers in valid_legacy_layers.values():
        known_layers.update(layers)
    if set(layer_dependencies) != known_layers:
        errors.append("layer_dependencies must define exactly the registered layers")
    for layer in known_layers:
        dependencies = layer_dependencies.get(layer)
        if not isinstance(dependencies, list):
            errors.append(f"layer {layer!r} must have a dependency list")
            continue
        if any(not isinstance(dependency, str) for dependency in dependencies):
            errors.append(f"layer {layer!r} has an invalid dependency")
            continue
        if len(dependencies) != len(set(dependencies)):
            errors.append(f"layer {layer!r} has duplicate dependencies")
        for dependency in dependencies:
            if dependency not in known_layers:
                errors.append(
                    f"layer {layer!r} depends on unknown layer {dependency!r}"
                )
            elif dependency == layer:
                errors.append(f"layer {layer!r} depends on itself")
    for environment, legacy_order in valid_legacy_layers.items():
        environment_order = deployment_order + legacy_order
        for layer in environment_order:
            dependencies = layer_dependencies.get(layer, [])
            if not isinstance(dependencies, list):
                continue
            for dependency in dependencies:
                if (
                    dependency not in environment_order
                    or environment_order.index(dependency)
                    >= environment_order.index(layer)
                ):
                    errors.append(
                        f"dependency {dependency!r} must precede layer {layer!r} "
                        f"in {environment}"
                    )
    for layer in deployment_order:
        dependencies = layer_dependencies.get(layer, [])
        if not isinstance(dependencies, list):
            continue
        for dependency in dependencies:
            if (
                dependency not in deployment_order
                or deployment_order.index(dependency) >= deployment_order.index(layer)
            ):
                errors.append(
                    f"dependency {dependency!r} must precede layer {layer!r}"
                )

    services = registry.get("services")
    if not isinstance(services, dict) or not services:
        errors.append("services must be a non-empty object")
        services = {}

    for service_name, service in services.items():
        if not IDENTIFIER.fullmatch(service_name):
            errors.append(f"invalid service identifier: {service_name!r}")
            continue
        if not isinstance(service, dict):
            errors.append(f"service {service_name!r} must be an object")
            continue

        layer = service.get("layer")
        if not isinstance(layer, str):
            errors.append(f"service {service_name!r} has invalid layer {layer!r}")
            continue
        if layer not in deployment_order and not any(
            layer in layers for layers in valid_legacy_layers.values()
        ):
            errors.append(f"service {service_name!r} has unknown layer {layer!r}")

        environments = service.get("environments")
        if (
            not isinstance(environments, list)
            or not environments
            or any(environment not in ENVIRONMENTS for environment in environments)
        ):
            errors.append(f"service {service_name!r} has invalid environments")
            environments = []

        modules = service.get("modules")
        if not isinstance(modules, dict) or not modules:
            errors.append(f"service {service_name!r} must map at least one provider")
            continue
        for provider, module_paths in modules.items():
            if not IDENTIFIER.fullmatch(provider):
                errors.append(
                    f"service {service_name!r} has invalid provider {provider!r}"
                )
                continue
            if not isinstance(module_paths, list) or not module_paths:
                errors.append(
                    f"service {service_name!r} provider {provider!r} "
                    "must map at least one module"
                )
                continue

            for module_path in module_paths:
                if not isinstance(module_path, str):
                    errors.append(
                        f"service {service_name!r} points to invalid module {module_path!r}"
                    )
                    continue
                relative_module = Path(module_path)
                module = (ROOT / relative_module).resolve()
                if (
                    relative_module.is_absolute()
                    or not relative_module.parts
                    or relative_module.parts[0] != "modules"
                    or module != ROOT / "modules" and ROOT / "modules" not in module.parents
                    or len(relative_module.parts) < 3
                    or relative_module.parts[1] != layer
                    or not (module / "version.tf").is_file()
                ):
                    errors.append(
                        f"service {service_name!r} points to invalid module {module_path!r}"
                    )

            for environment in environments:
                root = ROOT / "environments" / environment / provider / layer
                if not root.is_dir():
                    errors.append(
                        f"service {service_name!r} points to missing Terraform root {root}"
                    )

    return errors


def resolve_layers(registry, layer, environment, provider):
    dependencies = registry["layer_dependencies"]
    closure = set()

    def add_layer(current_layer):
        if current_layer in closure:
            return
        closure.add(current_layer)
        for dependency in dependencies.get(current_layer, []):
            add_layer(dependency)

    add_layer(layer)
    order = registry["deployment_order"] + registry.get(
        "legacy_layers", {}
    ).get(environment, [])
    resolved_layers = [candidate for candidate in order if candidate in closure]
    for resolved_layer in resolved_layers:
        root = ROOT / "environments" / environment / provider / resolved_layer
        if not root.is_dir():
            raise ValueError(f"Terraform root does not exist: {root}")
    return resolved_layers


def resolve_service(registry, service_name, provider, environment):
    if environment not in ENVIRONMENTS:
        raise ValueError(f"unsupported environment: {environment}")
    service = registry.get("services", {}).get(service_name)
    if service is None:
        raise ValueError(f"unknown service: {service_name}")
    if environment not in service["environments"]:
        raise ValueError(
            f"service {service_name!r} is not registered for {environment}"
        )
    if provider not in service["modules"]:
        raise ValueError(
            f"service {service_name!r} has no module registered for {provider}"
        )

    return resolve_layers(registry, service["layer"], environment, provider)


def main(arguments):
    if len(arguments) == 1 and arguments[0] == "validate":
        registry = load_registry()
        errors = validate_registry(registry)
        if errors:
            for error in errors:
                print(f"ERROR: {error}", file=sys.stderr)
            return 1
        print(f"Validated {len(registry['services'])} registered services.")
        return 0

    if len(arguments) == 2 and arguments[0] == "layers":
        registry = load_registry()
        environment = arguments[1]
        if environment not in ENVIRONMENTS:
            print(f"Unsupported environment: {environment}", file=sys.stderr)
            return 1
        layers = registry["deployment_order"] + registry.get(
            "legacy_layers", {}
        ).get(environment, [])
        print("\n".join(layers))
        return 0

    if len(arguments) == 4 and arguments[0] == "resolve":
        registry = load_registry()
        errors = validate_registry(registry)
        if errors:
            for error in errors:
                print(f"ERROR: {error}", file=sys.stderr)
            return 1
        try:
            print("\n".join(resolve_service(registry, *arguments[1:])))
            return 0
        except ValueError as error:
            print(f"ERROR: {error}", file=sys.stderr)
            return 1

    print(
        "Usage: service-registry.py validate | layers <environment> | "
        "resolve <service> <provider> <environment>",
        file=sys.stderr,
    )
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

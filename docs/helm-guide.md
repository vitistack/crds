# Vitistack CRDs Helm Chart Guide

This guide explains how to use and manage the Vitistack CRDs Helm chart.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
- [Upgrading](#upgrading)
- [Uninstallation](#uninstallation)
- [Development](#development)

## Overview

The Vitistack CRDs Helm chart provides a standardized way to install and manage Custom Resource Definitions (CRDs) for the Vitistack platform. This chart includes all necessary CRDs for managing infrastructure resources.

### CRDs Included

- `vitistacks.vitistack.io` - Core Vitistack resources
- `kubernetesclusters.vitistack.io` - Kubernetes cluster management
- `kubernetesproviders.vitistack.io` - Kubernetes provider configuration
- `kubevirtconfigs.vitistack.io` - KubeVirt configuration
- `loadbalancers.vitistack.io` - Load balancer resources
- `machineproviders.vitistack.io` - Machine provider configuration
- `machines.vitistack.io` - Machine resources
- `networkconfigurations.vitistack.io` - Network configuration
- `networknamespaces.vitistack.io` - Network namespace management
- `proxmoxconfigs.vitistack.io` - Proxmox configuration

## Prerequisites

- Kubernetes cluster (v1.19+)
- Helm 3.x installed
- `kubectl` configured to access your cluster

## Installation

### Install from OCI Registry (Recommended)

The Helm chart is published to GitHub Container Registry as an OCI artifact with every release:

```bash
# Install the latest version
helm install vitistack-crds oci://ghcr.io/vitistack/vitistack-crds

# Install a specific version
helm install vitistack-crds oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0
```

### Quick Start (From Source)

Install the CRDs directly from the chart directory:

```bash
helm install vitistack-crds ./charts/vitistack-crds
```

### Install with Custom Release Name

```bash
# From OCI registry
helm install my-vitistack-crds oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0

# From source
helm install my-vitistack-crds ./charts/vitistack-crds
```

### Install in a Specific Namespace

While CRDs are cluster-scoped, you may want to install the Helm release in a specific namespace:

```bash
# From OCI registry
helm install vitistack-crds oci://ghcr.io/vitistack/vitistack-crds \
  --version 0.1.0 \
  --create-namespace \
  --namespace vitistack-system

# From source
helm install vitistack-crds ./charts/vitistack-crds \
  --create-namespace \
  --namespace vitistack-system
```

### Pull Chart from OCI Registry

You can also pull the chart locally before installing:

```bash
# Pull the chart
helm pull oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0

# This downloads vitistack-crds-0.1.0.tgz
# Then install from the local file
helm install vitistack-crds vitistack-crds-0.1.0.tgz
```

### Install from a Packaged Chart

First, package the chart:

```bash
make helm-package
# or
helm package ./charts/vitistack-crds -d charts/
```

Then install the packaged chart:

```bash
helm install vitistack-crds charts/vitistack-crds-0.1.0.tgz
```

### Install with Custom Values

Create a custom values file:

```yaml
# custom-values.yaml
crds:
  keep: false

annotations:
  company.com/managed-by: "platform-team"
  company.com/environment: "production"

labels:
  environment: production
  team: platform
```

Install with custom values:

```bash
helm install vitistack-crds ./charts/vitistack-crds \
  -f custom-values.yaml
```

## Configuration

### Values

| Parameter     | Description                                         | Default |
| ------------- | --------------------------------------------------- | ------- |
| `crds.keep`   | Keep CRDs when uninstalling the chart (recommended) | `true`  |
| `annotations` | Additional annotations to add to all CRD resources  | `{}`    |
| `labels`      | Additional labels to add to all CRD resources       | `{}`    |

### Examples

#### Prevent CRD Deletion on Uninstall (Recommended)

This is the default behavior to protect your data:

```yaml
crds:
  keep: true
```

This adds the `helm.sh/resource-policy: keep` annotation to all CRDs.

#### Add Custom Annotations

```yaml
annotations:
  company.com/team: "platform"
  company.com/cost-center: "infrastructure"
```

#### Add Custom Labels

```yaml
labels:
  environment: staging
  managed-by: helm
  component: crds
```

## Usage

### Verify Installation

Check that CRDs are installed:

```bash
kubectl get crds | grep vitistack.io
```

Expected output:

```
kubernetesclusters.vitistack.io       2024-10-28T08:30:00Z
kubernetesproviders.vitistack.io      2024-10-28T08:30:00Z
kubevirtconfigs.vitistack.io          2024-10-28T08:30:00Z
loadbalancers.vitistack.io            2024-10-28T08:30:00Z
machineproviders.vitistack.io         2024-10-28T08:30:00Z
machines.vitistack.io                 2024-10-28T08:30:00Z
networkconfigurations.vitistack.io    2024-10-28T08:30:00Z
networknamespaces.vitistack.io        2024-10-28T08:30:00Z
proxmoxconfigs.vitistack.io           2024-10-28T08:30:00Z
vitistacks.vitistack.io               2024-10-28T08:30:00Z
```

### Check Helm Release Status

```bash
helm status vitistack-crds
```

### List Installed Charts

```bash
helm list
```

### Get Values

```bash
helm get values vitistack-crds
```

### Get All Information

```bash
helm get all vitistack-crds
```

## Upgrading

### Upgrade to Latest Version

```bash
helm upgrade vitistack-crds ./charts/vitistack-crds
```

### Upgrade with New Values

```bash
helm upgrade vitistack-crds ./charts/vitistack-crds \
  -f new-values.yaml
```

### Dry Run Before Upgrade

```bash
helm upgrade vitistack-crds ./charts/vitistack-crds \
  --dry-run --debug
```

### Rollback to Previous Version

```bash
helm rollback vitistack-crds
```

Rollback to a specific revision:

```bash
helm rollback vitistack-crds 1
```

## Uninstallation

### Standard Uninstall

By default, CRDs are kept to prevent data loss:

```bash
helm uninstall vitistack-crds
```

This removes the Helm release but keeps the CRDs installed.

### Force Delete CRDs

If you need to completely remove the CRDs (⚠️ **This will delete all custom resources**):

```bash
# Uninstall the chart
helm uninstall vitistack-crds

# Manually delete CRDs
kubectl delete crd vitistacks.vitistack.io
kubectl delete crd kubernetesclusters.vitistack.io
kubectl delete crd kubernetesproviders.vitistack.io
kubectl delete crd kubevirtconfigs.vitistack.io
kubectl delete crd loadbalancers.vitistack.io
kubectl delete crd machineproviders.vitistack.io
kubectl delete crd machines.vitistack.io
kubectl delete crd networkconfigurations.vitistack.io
kubectl delete crd networknamespaces.vitistack.io
kubectl delete crd proxmoxconfigs.vitistack.io
```

Or use a label selector (if you added labels):

```bash
kubectl delete crd -l app.kubernetes.io/instance=vitistack-crds
```

## Development

### Testing the Chart

#### Lint the Chart

```bash
make helm-lint
# or
helm lint charts/vitistack-crds
```

#### Render Templates

Test template rendering without installing:

```bash
make helm-template
# or
helm template vitistack-crds charts/vitistack-crds
```

#### Dry Run Install

```bash
helm install vitistack-crds ./charts/vitistack-crds \
  --dry-run --debug
```

### Packaging

Package the chart for distribution:

```bash
make helm-package
# or
helm package charts/vitistack-crds -d charts/
```

This creates a `.tgz` file that can be distributed and installed.

### Chart Structure

```
charts/vitistack-crds/
├── Chart.yaml                 # Chart metadata
├── values.yaml                # Default configuration values
├── .helmignore               # Files to ignore when packaging
├── README.md                 # Chart documentation
└── templates/
    ├── _helpers.tpl          # Template helpers
    ├── NOTES.txt            # Post-installation notes
    └── *.yaml               # CRD manifests
```

### Updating CRDs

When CRDs are updated:

1. Regenerate CRDs from source:

   ```bash
   make manifests
   ```

2. Copy updated CRDs to Helm chart:

   ```bash
   cp crds/*.yaml charts/vitistack-crds/templates/
   ```

3. Update chart version in `Chart.yaml`

4. Test the updated chart:

   ```bash
   make helm-lint
   make helm-template
   ```

5. Package and release:
   ```bash
   make helm-package
   ```

### Best Practices

1. **Always keep CRDs on uninstall** - Set `crds.keep: true` to prevent accidental data loss
2. **Version your charts** - Increment the version in `Chart.yaml` for each change
3. **Test before deploying** - Use `--dry-run` and `helm template` to verify changes
4. **Document changes** - Keep the `README.md` updated with configuration options
5. **Use semantic versioning** - Follow semver for chart versions

### Troubleshooting

#### CRDs Already Exist

If CRDs already exist from a previous installation:

```bash
# Check existing CRDs
kubectl get crds | grep vitistack.io

# If needed, delete and reinstall
kubectl delete crd -l app.kubernetes.io/name=vitistack-crds
helm install vitistack-crds ./charts/vitistack-crds
```

#### Template Rendering Errors

```bash
# Debug template rendering
helm template vitistack-crds ./charts/vitistack-crds --debug
```

#### Validation Errors

```bash
# Validate chart structure
helm lint charts/vitistack-crds

# Validate against Kubernetes API
helm install vitistack-crds ./charts/vitistack-crds --dry-run --debug
```

## CI/CD Integration

### GitLab CI Example

```yaml
helm-lint:
  stage: test
  script:
    - helm lint charts/vitistack-crds

helm-package:
  stage: build
  script:
    - helm package charts/vitistack-crds -d dist/
  artifacts:
    paths:
      - dist/*.tgz
```

### GitHub Actions Example

```yaml
name: Helm Chart

on: [push, pull_request]

jobs:
  lint-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: azure/setup-helm@v3
      - name: Lint chart
        run: helm lint charts/vitistack-crds
      - name: Test template
        run: helm template test charts/vitistack-crds
```

## Support

For issues, questions, or contributions:

- GitHub Issues: https://github.com/vitistack/crds/issues
- Documentation: https://github.com/vitistack/crds/tree/main/docs

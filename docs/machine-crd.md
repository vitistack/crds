# Machine CRD

The Machine Custom Resource Definition (CRD) provides a unified interface for creating and managing virtual machines across multiple cloud providers and virtualization platforms.

## Overview

The Machine CRD is designed to abstract the differences between various VM providers (AWS EC2, Azure VMs, GCP Compute Engine, VMware vSphere, OpenStack, etc.) while providing a consistent API for machine lifecycle management.

## Key Features

- **Multi-Provider Support**: Works with AWS, Azure, GCP, VMware vSphere, OpenStack, Libvirt, and Proxmox
- **Rich Configuration**: Comprehensive spec for CPU, memory, disks, networking, and OS configuration
- **Validation**: Built-in validation for resource limits and provider-specific constraints
- **Status Tracking**: Detailed status reporting including machine phase, conditions, and resource utilization
- **Extensible**: Provider-specific configurations through the `config` map

## Machine Phases

The machine lifecycle is tracked through the following phases:

- `Pending`: Machine resource created, waiting to be processed
- `Creating`: Machine is being provisioned by the provider
- `Running`: Machine is running and ready
- `Stopping`: Machine is being stopped
- `Stopped`: Machine is stopped but not terminated
- `Terminating`: Machine is being terminated/deleted
- `Terminated`: Machine has been successfully terminated
- `Failed`: Machine creation or operation failed

## Spec Fields

### Required Fields

| Field            | Type   | Description                                                     |
| ---------------- | ------ | --------------------------------------------------------------- |
| `name`           | string | Name of the machine                                             |
| `instanceType`   | string | Provider-specific instance type (e.g., t3.medium, Standard_B2s) |
| `os`             | object | Operating system configuration                                  |
| `providerConfig` | object | Cloud provider configuration                                    |

### Operating System (`os`)

| Field          | Type   | Required | Description                                  |
| -------------- | ------ | -------- | -------------------------------------------- |
| `family`       | string | Yes      | OS family: `linux` or `windows`              |
| `distribution` | string | Yes      | OS distribution (ubuntu, centos, rhel, etc.) |
| `version`      | string | Yes      | OS version                                   |
| `architecture` | string | No       | CPU architecture: `amd64`, `arm64`, `x86_64` |
| `imageID`      | string | No       | Provider-specific image ID                   |
| `imageFamily`  | string | No       | Image family or marketplace image            |

### Provider Configuration (`providerConfig`)

| Field            | Type              | Required | Description                                                           |
| ---------------- | ----------------- | -------- | --------------------------------------------------------------------- |
| `name`           | string            | Yes      | Provider name (aws, azure, gcp, vsphere, openstack, libvirt, proxmox) |
| `region`         | string            | Yes      | Provider region                                                       |
| `zone`           | string            | No       | Availability zone                                                     |
| `config`         | map[string]string | No       | Provider-specific configuration                                       |
| `credentialsRef` | object            | No       | Reference to credentials secret                                       |

### Optional Configuration

#### CPU Configuration

```yaml
cpu:
  cores: 4 # Number of CPU cores (1-256)
  threadsPerCore: 2 # Threads per core (1-8)
  sockets: 2 # Number of CPU sockets (1-16)
```

#### Memory Configuration

```yaml
memory: 8589934592 # Memory in bytes (minimum: 0)
```

#### Disk Configuration

```yaml
disks:
  - name: root # Disk name (required)
    sizeGB: 20 # Size in GB (1-65536)
    type: gp3 # Provider-specific disk type
    boot: true # Is this the boot disk?
    encrypted: true # Enable encryption
    iops: 3000 # IOPS (100-64000)
    throughput: 125 # Throughput in MB/s (125-4000)
```

#### Network Configuration

```yaml
network:
  vpc: vpc-12345678 # VPC/Virtual Network ID
  subnet: subnet-87654321 # Subnet ID
  assignPublicIP: true # Assign public IP
  privateIP: 10.0.1.100 # Static private IP
  publicIP: elastic-ip-123 # Static public IP/Elastic IP
  interfaces: # Network interfaces
    - name: eth0
      primary: true
      subnet: subnet-87654321
      securityGroups:
        - sg-web-server
```

#### Additional Options

```yaml
sshKeys: # SSH public keys
  - "ssh-rsa AAAAB3NzaC1yc2E..."

userData: | # Cloud-init user data script
  #!/bin/bash
  apt-get update
  apt-get install -y nginx

tags: # Resource tags/labels
  Environment: production
  Team: platform

securityGroups: # Security groups/firewall rules
  - sg-web-server
  - sg-monitoring

monitoring: true # Enable monitoring

backup: # Backup configuration
  enabled: true
  schedule: "0 2 * * *" # Cron schedule
  retentionDays: 30
```

## Status Fields

The Machine status provides comprehensive information about the machine's current state:

### Core Status

- `phase`: Current machine phase
- `message`: Detailed status message
- `providerID`: Provider-assigned unique identifier
- `machineID`: Internal machine identifier
- `state`: Current state from provider
- `lastUpdated`: Last status update timestamp

### Network Information

- `ipAddresses`: All IP addresses
- `ipv6Addresses`: IPv6 addresses
- `publicIPAddresses`: Public IP addresses
- `privateIPAddresses`: Private IP addresses
- `networkInterfaces`: Detailed network interface information

### Hardware Information

- `cpus`: Actual CPU count
- `memory`: Actual memory in bytes
- `architecture`: CPU architecture
- `disks`: Detailed disk information with usage

### System Information

- `hostname`: Machine hostname
- `operatingSystem`: Detected OS
- `operatingSystemVersion`: OS version
- `kernelVersion`: Kernel version
- `bootTime`: Machine boot time
- `creationTime`: Machine creation time

### Conditions

Machine conditions provide detailed status information:

- `Ready`: Machine is ready for use
- `NetworkReady`: Network is configured and ready
- `BootstrapReady`: Initial bootstrap completed
- `InfrastructureReady`: Infrastructure provisioning completed
- `DrainReady`: Machine is ready to be drained
- `BackupReady`: Backup system is ready

## Provider-Specific Examples

### AWS EC2

```yaml
instanceType: t3.medium
providerConfig:
  name: aws
  region: us-west-2
  zone: us-west-2a
  config:
    instanceProfile: EC2-WebServer-Role
    placementGroup: web-servers
    tenancy: default
```

### Azure Virtual Machines

```yaml
instanceType: Standard_B2s
providerConfig:
  name: azure
  region: westus2
  config:
    resourceGroup: rg-production
    availabilitySet: as-app-servers
```

### Google Compute Engine

```yaml
instanceType: n2-standard-4
providerConfig:
  name: gcp
  region: us-central1
  zone: us-central1-a
  config:
    project: my-gcp-project
    serviceAccount: vm-service-account@project.iam.gserviceaccount.com
```

### VMware vSphere

```yaml
instanceType: medium # Custom sizing
cpu:
  cores: 4
  sockets: 2
memory: 8589934592
providerConfig:
  name: vsphere
  region: vitistack-west
  config:
    vcenter: vcenter.example.com
    vitistack: DC-West
    cluster: Cluster-Prod
    datastore: datastore-ssd
```

## Usage with Operators

This CRD is designed to be used with machine provisioning operators that handle the provider-specific logic:

1. **Machine Controller**: Watches Machine resources and delegates to provider-specific controllers
2. **Provider Controllers**: Handle the actual machine lifecycle for each provider (AWS, Azure, etc.)
3. **Status Controllers**: Update machine status with real-time information from providers

## Best Practices

1. **Resource Sizing**: Use appropriate instance types and validate resource requirements
2. **Networking**: Configure security groups and network access carefully
3. **Storage**: Use encrypted disks for sensitive workloads
4. **Monitoring**: Enable monitoring for production workloads
5. **Backup**: Configure automated backups for stateful workloads
6. **Tags**: Use consistent tagging for cost allocation and management
7. **Credentials**: Store provider credentials securely in Kubernetes secrets

## Validation

The CRD includes comprehensive validation rules:

- CPU cores: 1-256
- CPU threads per core: 1-8
- CPU sockets: 1-16
- Disk size: 1-65536 GB
- Disk IOPS: 100-64000
- Disk throughput: 125-4000 MB/s
- Memory: minimum 0 bytes
- Provider names: enum validation
- OS family: linux or windows
- Required fields validation

This ensures that machine specifications are valid before they reach the provider controllers.

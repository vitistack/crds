# Datacenter CRD Documentation

## Overview

The Datacenter Custom Resource Definition (CRD) represents a logical datacenter that ties together machine providers and Kubernetes providers within a specific geographical region or zone. It provides comprehensive configuration for networking, security, monitoring, backup, and resource management across multi-cloud and on-premises environments.

## Purpose

- **Provider Orchestration**: Coordinate multiple machine and Kubernetes providers within a datacenter
- **Resource Management**: Define quotas and limits for compute, storage, and network resources
- **Security Governance**: Enforce compliance frameworks, encryption, and access controls
- **Operational Excellence**: Configure monitoring, backup, and disaster recovery policies
- **Network Management**: Define VPCs, subnets, load balancers, and firewall rules
- **Multi-Cloud Support**: Support AWS, Azure, GCP, VMware vSphere, and other providers

## API Version

- **Group**: `vitistack.io`
- **Version**: `v1alpha1`
- **Kind**: `Datacenter`

## Resource Scope

- **Scope**: Namespaced
- **Short Name**: `dc`

## Spec Fields

### Core Configuration

| Field         | Type   | Required | Description                                         |
| ------------- | ------ | -------- | --------------------------------------------------- |
| `displayName` | string | ✅       | Human-readable name for the datacenter              |
| `description` | string | ❌       | Additional context about the datacenter             |
| `region`      | string | ✅       | Geographical region where the datacenter is located |
| `zone`        | string | ❌       | Availability zone within the region                 |
| `location`    | object | ❌       | Detailed location information including coordinates |

### Provider References

| Field                 | Type  | Required | Description                                               |
| --------------------- | ----- | -------- | --------------------------------------------------------- |
| `machineProviders`    | array | ✅       | List of machine providers available in this datacenter    |
| `kubernetesProviders` | array | ❌       | List of Kubernetes providers available in this datacenter |

#### Provider Reference Structure

```yaml
machineProviders:
  - name: string # Provider resource name (required)
    namespace: string # Provider namespace (optional)
    priority: int32 # Preference order (1 = highest)
    enabled: bool # Whether provider is active
    configuration: map # Provider-specific settings
```

### Networking Configuration

| Field                      | Type   | Required | Description                     |
| -------------------------- | ------ | -------- | ------------------------------- |
| `networking.vpcs`          | array  | ❌       | Virtual private clouds/networks |
| `networking.loadBalancers` | array  | ❌       | Load balancer configurations    |
| `networking.dns`           | object | ❌       | DNS configuration               |
| `networking.firewall`      | object | ❌       | Firewall rules and policies     |

#### VPC Structure

```yaml
vpcs:
  - name: string # VPC name (required)
    cidr: string # CIDR block (required, validated)
    default: bool # Whether this is the default VPC
    subnets: # Subnets within the VPC
      - name: string # Subnet name (required)
        cidr: string # Subnet CIDR (required, validated)
        zone: string # Availability zone
        public: bool # Whether subnet has internet access
```

#### Load Balancer Structure

```yaml
loadBalancers:
  - name: string # Load balancer name (required)
    type: string # Type: application, network, classic
    scheme: string # internet-facing or internal
```

#### DNS Configuration

```yaml
dns:
  servers: [string] # DNS server addresses
  domain: string # Default domain
  searchDomains: [string] # Search domains for resolution
```

#### Firewall Configuration

```yaml
firewall:
  defaultPolicy: string # Default policy: allow or deny
  rules: # Specific firewall rules
    - name: string # Rule name (required)
      action: string # Action: allow or deny (required)
      protocol: string # Protocol: tcp, udp, icmp, all
      port: string # Port or port range
      source: string # Source CIDR or IP range
      destination: string # Destination CIDR or IP range
```

### Security Configuration

| Field                           | Type   | Required | Description                    |
| ------------------------------- | ------ | -------- | ------------------------------ |
| `security.complianceFrameworks` | array  | ❌       | Required compliance frameworks |
| `security.encryption`           | object | ❌       | Encryption requirements        |
| `security.accessControl`        | object | ❌       | Access control policies        |
| `security.auditLogging`         | object | ❌       | Audit logging configuration    |

#### Encryption Configuration

```yaml
encryption:
  atRest: bool # Data at rest encryption (default: true)
  inTransit: bool # Data in transit encryption (default: true)
  keyManagement: string # Key management service
```

#### Access Control Configuration

```yaml
accessControl:
  rbac: bool # Role-based access control (default: true)
  mfa: bool # Multi-factor authentication required
  allowedUsers: [string] # Permitted users
  allowedGroups: [string] # Permitted groups
```

#### Audit Logging Configuration

```yaml
auditLogging:
  enabled: bool # Enable audit logging (default: true)
  retentionDays: int32 # Log retention period (1-2555 days)
  destination: string # Log destination: local, s3, azure, gcs, elasticsearch
```

### Monitoring Configuration

| Field                             | Type  | Required | Description                           |
| --------------------------------- | ----- | -------- | ------------------------------------- |
| `monitoring.enabled`              | bool  | ❌       | Enable monitoring (default: true)     |
| `monitoring.metricsRetentionDays` | int32 | ❌       | Metrics retention period (1-365 days) |
| `monitoring.alertingEnabled`      | bool  | ❌       | Enable alerting (default: true)       |
| `monitoring.alertReceivers`       | array | ❌       | Alert contact points                  |
| `monitoring.customDashboards`     | array | ❌       | Custom monitoring dashboards          |

### Backup and Disaster Recovery

| Field                     | Type   | Required | Description                     |
| ------------------------- | ------ | -------- | ------------------------------- |
| `backup.enabled`          | bool   | ❌       | Enable backup (default: true)   |
| `backup.schedule`         | string | ❌       | Backup schedule (cron format)   |
| `backup.retentionPolicy`  | object | ❌       | Backup retention policies       |
| `backup.destinations`     | array  | ❌       | Backup storage destinations     |
| `backup.disasterRecovery` | object | ❌       | Disaster recovery configuration |

#### Backup Retention Policy

```yaml
retentionPolicy:
  daily: int32 # Daily backups to keep (default: 7)
  weekly: int32 # Weekly backups to keep (default: 4)
  monthly: int32 # Monthly backups to keep (default: 12)
```

#### Backup Destination

```yaml
destinations:
  - name: string # Destination name (required)
    type: string # Type: s3, azure, gcs, local, nfs (required)
    configuration: map # Destination-specific config
    encryption: bool # Enable encryption for destination
```

#### Disaster Recovery Configuration

```yaml
disasterRecovery:
  enabled: bool # Enable disaster recovery
  targetDatacenter: string # Target datacenter for DR
  rpoMinutes: int32 # Recovery Point Objective (minutes)
  rtoMinutes: int32 # Recovery Time Objective (minutes)
```

### Resource Quotas

| Field                                 | Type  | Required | Description                           |
| ------------------------------------- | ----- | -------- | ------------------------------------- |
| `resourceQuotas.maxMachines`          | int32 | ❌       | Maximum number of machines            |
| `resourceQuotas.maxClusters`          | int32 | ❌       | Maximum number of Kubernetes clusters |
| `resourceQuotas.maxCPUCores`          | int32 | ❌       | Maximum total CPU cores               |
| `resourceQuotas.maxMemoryGB`          | int32 | ❌       | Maximum total memory in GB            |
| `resourceQuotas.maxStorageGB`         | int32 | ❌       | Maximum total storage in GB           |
| `resourceQuotas.maxNetworkInterfaces` | int32 | ❌       | Maximum network interfaces            |

### Tags

| Field  | Type | Required | Description                                                 |
| ------ | ---- | -------- | ----------------------------------------------------------- |
| `tags` | map  | ❌       | Key-value pairs for organizing and categorizing datacenters |

## Status Fields

The status section provides real-time information about the datacenter's operational state.

### Core Status

| Field                     | Type   | Description                                         |
| ------------------------- | ------ | --------------------------------------------------- |
| `phase`                   | string | Current datacenter phase                            |
| `conditions`              | array  | Latest observations of datacenter state             |
| `machineProviderCount`    | int32  | Number of active machine providers                  |
| `kubernetesProviderCount` | int32  | Number of active Kubernetes providers               |
| `activeMachines`          | int32  | Number of active machines                           |
| `activeClusters`          | int32  | Number of active Kubernetes clusters                |
| `lastReconcileTime`       | time   | When the datacenter was last reconciled             |
| `observedGeneration`      | int64  | Generation of the most recently observed Datacenter |

### Resource Usage

```yaml
resourceUsage:
  cpuCoresUsed: int32 # Used CPU cores
  cpuCoresTotal: int32 # Total available CPU cores
  memoryGBUsed: int32 # Used memory in GB
  memoryGBTotal: int32 # Total available memory in GB
  storageGBUsed: int32 # Used storage in GB
  storageGBTotal: int32 # Total available storage in GB
  networkInterfacesUsed: int32 # Used network interfaces
  networkInterfacesTotal: int32 # Total available network interfaces
```

### Provider Statuses

```yaml
providerStatuses:
  - name: string # Provider name
    type: string # Provider type: machine or kubernetes
    phase: string # Provider phase
    healthy: bool # Provider health status
    lastHealthCheck: time # Last health check time
    message: string # Status message
    resourcesManaged: int32 # Resources managed by provider
```

## Phases

| Phase          | Description                     |
| -------------- | ------------------------------- |
| `Initializing` | Datacenter is being initialized |
| `Provisioning` | Resources are being provisioned |
| `Ready`        | Datacenter is operational       |
| `Degraded`     | Some components are unhealthy   |
| `Deleting`     | Datacenter is being deleted     |
| `Failed`       | Datacenter setup failed         |

## Conditions

| Type                | Description                    |
| ------------------- | ------------------------------ |
| `Ready`             | Datacenter is ready for use    |
| `ProvidersHealthy`  | All providers are healthy      |
| `NetworkingReady`   | Network configuration is ready |
| `MonitoringReady`   | Monitoring is configured       |
| `BackupReady`       | Backup is configured           |
| `SecurityCompliant` | Security policies are enforced |
| `QuotaAvailable`    | Resource quotas are available  |

## Validation Rules

### CIDR Validation

- VPC and subnet CIDR blocks must be valid IPv4 CIDR notation
- Pattern: `^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$`

### Coordinate Validation

- Latitude: -90 to 90 degrees (validated by regex pattern)
- Longitude: -180 to 180 degrees (validated by regex pattern)

### Enum Validations

- Load balancer type: `application`, `network`, `classic`
- Load balancer scheme: `internet-facing`, `internal`
- Firewall policy: `allow`, `deny`
- Firewall protocol: `tcp`, `udp`, `icmp`, `all`
- Firewall action: `allow`, `deny`
- Backup destination type: `s3`, `azure`, `gcs`, `local`, `nfs`
- Audit log destination: `local`, `s3`, `azure`, `gcs`, `elasticsearch`

### Numeric Constraints

- Retention days: 1-2555 days for audit logs
- Metrics retention: 1-365 days
- Provider priority: minimum 1
- Resource quotas: minimum 1 where specified

## Printer Columns

When listing datacenters with `kubectl get datacenters`, the following columns are displayed:

| Column            | Description                    |
| ----------------- | ------------------------------ |
| NAME              | Datacenter name                |
| PHASE             | Current phase                  |
| REGION            | Geographical region            |
| MACHINE PROVIDERS | Number of machine providers    |
| K8S PROVIDERS     | Number of Kubernetes providers |
| READY             | Ready condition status         |
| AGE               | Age of the datacenter          |

## Examples

### Multi-Cloud Enterprise Datacenter

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: enterprise-datacenter-east
  namespace: production
spec:
  displayName: "Enterprise Datacenter East"
  region: us-east-1
  zone: us-east-1a

  machineProviders:
    - name: aws-us-east-1
      priority: 1
      enabled: true
    - name: azure-eastus
      priority: 2
      enabled: true

  kubernetesProviders:
    - name: eks-provider
      priority: 1
      enabled: true

  networking:
    vpcs:
      - name: production-vpc
        cidr: "10.0.0.0/16"
        default: true
        subnets:
          - name: production-subnet-1a
            cidr: "10.0.1.0/24"
            zone: us-east-1a
            public: false

  security:
    complianceFrameworks: ["SOC2", "ISO27001"]
    encryption:
      atRest: true
      inTransit: true
    accessControl:
      rbac: true
      mfa: true

  resourceQuotas:
    maxMachines: 1000
    maxClusters: 50
    maxCPUCores: 10000
    maxMemoryGB: 50000
```

### Edge Datacenter

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: edge-datacenter-west
  namespace: edge
spec:
  displayName: "Edge Datacenter West"
  region: us-west-2

  machineProviders:
    - name: aws-us-west-2
      priority: 1
      enabled: true

  resourceQuotas:
    maxMachines: 50
    maxClusters: 5
    maxCPUCores: 500
    maxMemoryGB: 2000
```

### On-Premises Datacenter

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: onprem-datacenter-hq
  namespace: onprem
spec:
  displayName: "Headquarters Datacenter"
  region: on-premises
  location:
    country: "United States"
    city: "San Francisco"

  machineProviders:
    - name: vsphere-cluster-a
      priority: 1
      enabled: true
      configuration:
        vcenter: "vcenter.company.com"
        datacenter: "HQ-DC"

  kubernetesProviders:
    - name: rancher-provider
      priority: 1
      enabled: true

  networking:
    vpcs:
      - name: corporate-network
        cidr: "192.168.0.0/16"
        default: true

  backup:
    destinations:
      - name: primary-nas
        type: nfs
        configuration:
          server: "nas01.company.local"
          path: "/backups/datacenter"
```

## Best Practices

### Security

1. **Enable Encryption**: Always enable both at-rest and in-transit encryption
2. **Compliance Frameworks**: Specify required compliance frameworks
3. **Access Control**: Use RBAC and consider MFA for sensitive environments
4. **Audit Logging**: Enable comprehensive audit logging with appropriate retention

### Networking

1. **CIDR Planning**: Plan CIDR blocks to avoid conflicts between datacenters
2. **Subnet Design**: Use separate subnets for different workload types
3. **Firewall Rules**: Follow principle of least privilege for firewall rules
4. **Load Balancers**: Configure appropriate load balancer types for workloads

### Resource Management

1. **Quotas**: Set realistic resource quotas based on capacity and requirements
2. **Provider Priority**: Set priorities to prefer certain providers over others
3. **Monitoring**: Enable monitoring with appropriate retention periods
4. **Backup**: Configure regular backups with multiple destinations

### High Availability

1. **Multi-Zone**: Distribute resources across multiple availability zones
2. **Provider Redundancy**: Use multiple providers for critical workloads
3. **Disaster Recovery**: Configure disaster recovery for production environments
4. **Health Checks**: Monitor provider health and configure alerting

### Cost Optimization

1. **Resource Limits**: Set appropriate limits to prevent cost overruns
2. **Backup Retention**: Balance retention requirements with storage costs
3. **Monitoring Retention**: Optimize metrics retention based on needs
4. **Provider Selection**: Choose cost-effective providers based on workload requirements

## Troubleshooting

### Common Issues

1. **Provider Not Ready**: Check provider authentication and network connectivity
2. **Resource Quota Exceeded**: Monitor resource usage and adjust quotas
3. **Network Connectivity**: Verify VPC and subnet configurations
4. **Backup Failures**: Check backup destination credentials and permissions

### Debugging Commands

```bash
# List all datacenters
kubectl get datacenters

# Get detailed datacenter information
kubectl describe datacenter <name>

# Check datacenter status
kubectl get datacenter <name> -o jsonpath='{.status.phase}'

# View provider statuses
kubectl get datacenter <name> -o jsonpath='{.status.providerStatuses}'

# Check resource usage
kubectl get datacenter <name> -o jsonpath='{.status.resourceUsage}'
```

## Related Resources

- [Machine CRD Documentation](machine-crd.md)
- [MachineProvider CRD Documentation](machine-provider-crd.md)
- [KubernetesProvider CRD Documentation](kubernetes-provider-crd.md)
- [Architecture Overview](architecture.md)

## API Reference

For complete API reference including all fields, validations, and examples, see the generated OpenAPI schema in the CRD definition file: `crds/vitistack.io_datacenters.yaml`.

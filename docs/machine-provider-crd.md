# MachineProvider CRD Documentation

## Overview

The `MachineProvider` Custom Resource Definition (CRD) manages virtualization and cloud provider configurations for machine provisioning. It defines provider-specific settings, authentication, networking, storage, and compute capabilities that can be referenced by Machine resources.

## API Version

- **Group**: `vitistack.io`
- **Version**: `v1alpha1`
- **Kind**: `MachineProvider`

## Resource Structure

### Metadata

Standard Kubernetes metadata with additional printer columns:

- **Name**: Provider name
- **Type**: Provider type (aws, azure, gcp, vsphere, etc.)
- **Region**: Primary region/datacenter
- **Ready**: Provider readiness status
- **Age**: Resource age

### Spec Fields

#### Provider Configuration

```yaml
spec:
  type: string                    # Provider type (aws, azure, gcp, vsphere, openstack, libvirt, proxmox)
  region: string                  # Primary region or datacenter location
  availabilityZones: []string     # Available zones within the region

  # Provider-specific configuration
  config:
    endpoint: string              # Provider API endpoint
    version: string              # API version to use
    timeout: string              # Request timeout (e.g., "30s", "5m")
    retryPolicy:
      maxRetries: int32          # Maximum retry attempts
      backoffMultiplier: string  # Backoff multiplier (e.g., "1.5")
      maxBackoffDelay: string    # Maximum backoff delay

    # Rate limiting
    rateLimiting:
      requestsPerSecond: string  # Requests per second (e.g., "10.5")
      burstLimit: int32          # Burst request limit

    # Custom provider settings
    customSettings: map[string]string
```

#### Authentication

```yaml
spec:
  authentication:
    type: string                 # auth type: apikey, oauth2, certificate, serviceaccount

    # API Key authentication
    apiKey:
      secretRef:
        name: string            # Secret name containing API key
        key: string             # Key within secret

    # OAuth2 authentication
    oauth2:
      clientId: string
      clientSecretRef:
        name: string
        key: string
      tokenURL: string
      scopes: []string

    # Certificate authentication
    certificate:
      certSecretRef:
        name: string
        key: string
      keySecretRef:
        name: string
        key: string

    # Service account authentication
    serviceAccount:
      secretRef:
        name: string
        key: string
```

#### Capabilities

```yaml
spec:
  capabilities:
    # Supported machine operations
    supportedOperations: []string  # create, delete, start, stop, restart, resize

    # Supported operating systems
    supportedOSTypes: []string     # linux, windows, freebsd, etc.

    # Supported instance types/flavors
    supportedInstanceTypes: []string

    # Available machine images
    availableImages:
    - name: string
      id: string
      osType: string
      version: string
      architecture: string        # x86_64, arm64, etc.
      description: string

    # Feature support flags
    features:
      snapshotSupport: bool
      liveResize: bool
      hotPlugDisks: bool
      hotPlugNetworks: bool
      customMetadata: bool
      tagSupport: bool
      monitoringIntegration: bool
      backupIntegration: bool
```

#### Network Configuration

```yaml
spec:
  networkConfig:
    # Default network settings
    defaultNetworkId: string
    defaultSubnetId: string

    # Available networks
    availableNetworks:
      - id: string
        name: string
        cidr: string
        type: string # public, private, management
        vlan: int32

    # Security groups/firewall rules
    securityGroups:
      - id: string
        name: string
        description: string
        rules:
          - protocol: string # tcp, udp, icmp
            port: string # port or range (e.g., "22", "80-443")
            source: string # CIDR or security group ID
            direction: string # ingress, egress

    # Load balancer configuration
    loadBalancer:
      enabled: bool
      type: string # application, network, classic
      algorithm: string # round-robin, least-connections, ip-hash
      healthCheck:
        protocol: string
        port: int32
        path: string
        interval: string
        timeout: string
        healthyThreshold: int32
        unhealthyThreshold: int32
```

#### Storage Configuration

```yaml
spec:
  storageConfig:
    # Default storage settings
    defaultStorageClass: string
    defaultDiskSize: string # e.g., "20Gi"

    # Available storage types
    availableStorageTypes:
      - name: string
        type: string # ssd, hdd, nvme
        iopsPerGB: string # IOPS per GB (e.g., "3.0")
        throughputMBps: string # Throughput in MB/s
        encrypted: bool
        replication: string # none, raid1, raid5, raid10

    # Backup configuration
    backup:
      enabled: bool
      retentionDays: int32
      schedule: string # cron expression
      destination: string # s3, gcs, azure-blob, local
      encryption: bool
```

#### Compute Configuration

```yaml
spec:
  computeConfig:
    # Resource limits and defaults
    defaultCPU: string          # e.g., "2"
    defaultMemoryGB: string     # e.g., "4.0"
    maxCPU: string
    maxMemoryGB: string

    # CPU configuration
    cpuOptions:
      hyperThreading: bool
      supportedArchitectures: []string  # x86_64, arm64
      cpuFeatures: []string             # avx, avx2, sse4, etc.

    # Memory configuration
    memoryOptions:
      hugePagesSupport: bool
      memoryOvercommit: bool
      swapEnabled: bool

    # GPU support
    gpuSupport:
      enabled: bool
      availableTypes: []string          # nvidia-tesla-v100, nvidia-rtx-3080, etc.
      maxGPUs: int32
```

### Status Fields

#### Provider Status

```yaml
status:
  # Overall provider state
  phase: string                 # Ready, NotReady, Error, Initializing

  # Detailed conditions
  conditions:
  - type: string               # Ready, Authenticated, NetworkConfigured, etc.
    status: string             # True, False, Unknown
    lastTransitionTime: string
    reason: string
    message: string

  # Connection status
  connectivity:
    status: string             # Connected, Disconnected, Error
    lastChecked: string
    endpoint: string
    latencyMs: int32

  # Authentication status
  authentication:
    status: string             # Valid, Invalid, Expired, Error
    lastVerified: string
    expiresAt: string

  # Resource usage and limits
  resources:
    # Current usage
    usage:
      machines: int32          # Number of machines managed
      totalCPU: string         # Total CPU allocated
      totalMemoryGB: string    # Total memory allocated
      totalStorageGB: string   # Total storage allocated

    # Provider limits
    limits:
      maxMachines: int32
      maxCPU: string
      maxMemoryGB: string
      maxStorageGB: string

    # Quota information
    quotas:
    - resource: string         # cpu, memory, storage, instances
      used: string
      limit: string
      available: string
      unit: string

  # Health metrics
  health:
    score: int32              # Health score 0-100
    lastChecked: string
    metrics:
      successRate: string     # Success rate percentage
      avgResponseTime: string # Average response time
      errorRate: string       # Error rate percentage

  # Capability status
  capabilities:
    verified: []string        # List of verified capabilities
    unsupported: []string     # List of unsupported features
    lastVerified: string
```

## Validation Rules

### Required Fields

- `spec.type`: Must be one of the supported provider types
- `spec.region`: Must be a non-empty string
- `spec.authentication`: At least one authentication method must be configured

### Field Constraints

- `spec.config.timeout`: Must match duration format (e.g., "30s", "5m")
- `spec.config.rateLimiting.requestsPerSecond`: Must match decimal string pattern
- `spec.networkConfig.availableNetworks[].cidr`: Must be valid CIDR notation
- `spec.storageConfig.defaultDiskSize`: Must match Kubernetes quantity format
- `spec.computeConfig.defaultCPU`: Must be positive decimal string
- `spec.computeConfig.defaultMemoryGB`: Must be positive decimal string

### Provider-Specific Validations

- **AWS**: Requires valid region format (e.g., "us-west-2")
- **Azure**: Requires valid resource group and subscription ID
- **GCP**: Requires valid project ID and zone format
- **vSphere**: Requires valid datacenter and cluster names
- **OpenStack**: Requires valid tenant and domain configuration

## Examples

### AWS Provider

```yaml
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: aws-us-west-2
  namespace: default
spec:
  type: aws
  region: us-west-2
  availabilityZones:
    - us-west-2a
    - us-west-2b
    - us-west-2c

  config:
    endpoint: ec2.us-west-2.amazonaws.com
    timeout: 30s
    rateLimiting:
      requestsPerSecond: "10.0"
      burstLimit: 20

  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: aws-credentials
        key: access-key-id

  capabilities:
    supportedOperations:
      - create
      - delete
      - start
      - stop
      - restart
      - resize
    supportedOSTypes:
      - linux
      - windows
    supportedInstanceTypes:
      - t3.micro
      - t3.small
      - m5.large
      - c5.xlarge

  networkConfig:
    defaultNetworkId: vpc-12345678
    availableNetworks:
      - id: subnet-11111111
        name: public-subnet-2a
        cidr: 10.0.1.0/24
        type: public
      - id: subnet-22222222
        name: private-subnet-2a
        cidr: 10.0.2.0/24
        type: private

  storageConfig:
    defaultStorageClass: gp3
    defaultDiskSize: 20Gi
    availableStorageTypes:
      - name: gp3
        type: ssd
        iopsPerGB: "3.0"
        encrypted: true
      - name: st1
        type: hdd
        throughputMBps: "40.0"

  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "4.0"
    maxCPU: "96"
    maxMemoryGB: "384.0"
```

### VMware vSphere Provider

```yaml
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: vsphere-datacenter1
  namespace: default
spec:
  type: vsphere
  region: datacenter1
  availabilityZones:
    - cluster1
    - cluster2

  config:
    endpoint: vcenter.example.com
    version: "7.0"
    timeout: 60s
    customSettings:
      datacenter: "Datacenter1"
      datastore: "datastore1"
      resourcePool: "pool1"

  authentication:
    type: certificate
    certificate:
      certSecretRef:
        name: vsphere-certs
        key: tls.crt
      keySecretRef:
        name: vsphere-certs
        key: tls.key

  capabilities:
    supportedOperations:
      - create
      - delete
      - start
      - stop
      - restart
      - resize
    supportedOSTypes:
      - linux
      - windows
    availableImages:
      - name: ubuntu-20.04-server
        id: vm-template-ubuntu2004
        osType: linux
        version: "20.04"
        architecture: x86_64
      - name: windows-server-2019
        id: vm-template-win2019
        osType: windows
        version: "2019"
        architecture: x86_64

  networkConfig:
    defaultNetworkId: "VM Network"
    availableNetworks:
      - id: "VM Network"
        name: "VM Network"
        type: management
      - id: "Production Network"
        name: "Production Network"
        type: private
        vlan: 100

  storageConfig:
    defaultStorageClass: thin
    defaultDiskSize: 50Gi
    availableStorageTypes:
      - name: thin
        type: ssd
        replication: none
      - name: thick-eager
        type: ssd
        replication: none

  computeConfig:
    defaultCPU: "4"
    defaultMemoryGB: "8.0"
    maxCPU: "32"
    maxMemoryGB: "256.0"
    cpuOptions:
      hyperThreading: true
      supportedArchitectures:
        - x86_64
```

## Best Practices

1. **Authentication Security**

   - Store sensitive credentials in Kubernetes Secrets
   - Use least-privilege access policies
   - Regularly rotate authentication credentials

2. **Resource Management**

   - Set reasonable default resource allocations
   - Monitor quota usage and provider limits
   - Implement proper resource cleanup policies

3. **Network Configuration**

   - Define clear network segmentation policies
   - Use security groups to restrict access
   - Configure proper DNS and routing

4. **Storage Best Practices**

   - Enable encryption for sensitive workloads
   - Configure appropriate backup policies
   - Monitor storage performance and costs

5. **Monitoring and Observability**
   - Implement health checks and monitoring
   - Set up alerting for provider issues
   - Log provider interactions for troubleshooting

## Troubleshooting

### Common Issues

1. **Authentication Failures**

   - Verify credentials are correct and not expired
   - Check network connectivity to provider endpoints
   - Ensure proper RBAC permissions

2. **Resource Quota Exceeded**

   - Check provider quota limits
   - Monitor resource usage trends
   - Request quota increases if needed

3. **Network Connectivity Issues**

   - Verify network configuration and security groups
   - Check DNS resolution and routing
   - Test connectivity from different zones

4. **Storage Performance Issues**
   - Monitor IOPS and throughput metrics
   - Consider upgrading storage types
   - Check for storage contention

### Debugging Commands

```bash
# Check provider status
kubectl get machineprovider -o wide

# Describe provider details
kubectl describe machineprovider <provider-name>

# Check provider logs
kubectl logs -l app=machine-controller

# Validate provider configuration
kubectl apply --dry-run=client -f provider.yaml
```

This documentation provides comprehensive guidance for configuring and managing MachineProvider resources across different virtualization and cloud platforms.

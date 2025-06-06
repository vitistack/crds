# KubernetesProvider CRD Documentation

## Overview

The `KubernetesProvider` Custom Resource Definition (CRD) manages Kubernetes cluster provisioning and configuration across different cloud providers and on-premises environments. It defines cluster specifications, node pools, networking, security, monitoring, and operational settings.

## API Version

- **Group**: `vitistack.io`
- **Version**: `v1alpha1`
- **Kind**: `KubernetesProvider`

## Resource Structure

### Metadata

Standard Kubernetes metadata with additional printer columns:

- **Name**: Provider name
- **Type**: Provider type (eks, aks, gke, rke2, k3s, etc.)
- **Version**: Kubernetes version
- **Nodes**: Total node count
- **Ready**: Provider readiness status
- **Age**: Resource age

### Spec Fields

#### Cluster Configuration

```yaml
spec:
  type: string # Provider type (eks, aks, gke, rke2, k3s, kubeadm, openshift)
  version: string # Kubernetes version (e.g., "1.28.0")
  region: string # Cloud region or datacenter

  # Cluster basic settings
  clusterConfig:
    name: string # Cluster name
    displayName: string # Human-readable display name
    description: string # Cluster description

    # High availability configuration
    highAvailability:
      enabled: bool # Enable HA control plane
      controlPlaneNodes: int32 # Number of control plane nodes (typically 3 or 5)

    # Cluster networking
    networking:
      serviceCIDR: string # Service network CIDR (e.g., "10.43.0.0/16")
      podCIDR: string # Pod network CIDR (e.g., "10.42.0.0/16")
      clusterDNS: string # Cluster DNS service IP
      dnsProvider: string # coredns, kube-dns

    # Container runtime
    containerRuntime: string # containerd, cri-o, docker

    # Cluster addons
    addons:
      dashboard: bool # Enable Kubernetes dashboard
      ingressController: bool # Enable ingress controller
      storageClasses: bool # Create default storage classes
      networkPolicies: bool # Enable network policies
      podSecurityPolicies: bool # Enable pod security policies

    # Custom configuration options
    customConfig: map[string]string
```

#### Node Pool Configuration

```yaml
spec:
  nodePools:
  - name: string                 # Node pool name
    role: string                 # master, worker, edge

    # Node specifications
    nodeConfig:
      instanceType: string       # Instance type/flavor
      imageId: string           # OS image ID
      diskSize: string          # Boot disk size (e.g., "100Gi")
      diskType: string          # ssd, hdd, nvme

    # Scaling configuration
    scaling:
      minNodes: int32           # Minimum number of nodes
      maxNodes: int32           # Maximum number of nodes
      desiredNodes: int32       # Desired number of nodes

      # Auto-scaling settings
      autoScaling:
        enabled: bool
        scaleUpCooldown: string   # e.g., "5m"
        scaleDownCooldown: string
        cpuThreshold: string      # CPU utilization threshold (e.g., "80.0")
        memoryThreshold: string   # Memory utilization threshold

    # Node placement
    placement:
      availabilityZones: []string
      nodeAffinity: {}           # Kubernetes node affinity rules
      taints: []string          # Node taints
      labels: map[string]string  # Node labels

    # Node configuration
    nodeOptions:
      kubeletArgs: map[string]string
      kernelModules: []string
      sysctls: map[string]string
      preInstallCommands: []string
      postInstallCommands: []string
```

#### Network Configuration

```yaml
spec:
  networkConfig:
    # Network provider/CNI
    cni: string                  # calico, flannel, cilium, weave, antrea

    # CNI configuration
    cniConfig:
      version: string
      customConfig: map[string]string

    # Load balancer configuration
    loadBalancer:
      type: string              # cloud, metallb, traefik, nginx, haproxy
      enabled: bool

      # Cloud load balancer settings
      cloudLB:
        scheme: string          # internet-facing, internal
        ipAddressType: string   # ipv4, dualstack
        sslPolicy: string

      # MetalLB configuration (for on-premises)
      metallb:
        addressPools:
        - name: string
          addresses: []string   # IP address ranges
          protocol: string      # layer2, bgp

    # Ingress configuration
    ingress:
      enabled: bool
      controller: string        # nginx, traefik, istio, ambassador
      className: string

      # Ingress controller configuration
      controllerConfig:
        replicas: int32
        resources:
          requests:
            cpu: string
            memory: string
          limits:
            cpu: string
            memory: string

    # Service mesh configuration
    serviceMesh:
      enabled: bool
      provider: string          # istio, linkerd, consul-connect
      version: string
      config: map[string]string
```

#### Security Configuration

```yaml
spec:
  securityConfig:
    # RBAC settings
    rbac:
      enabled: bool
      strictMode: bool          # Enable strict RBAC mode

    # Pod security configuration
    podSecurity:
      podSecurityStandard: string  # privileged, baseline, restricted
      enforce: bool
      audit: bool
      warn: bool

    # Network security
    networkSecurity:
      networkPolicies: bool     # Enable network policies by default
      pspEnabled: bool          # Pod Security Policies
      defaultDenyAll: bool      # Default deny all network traffic

    # Secrets management
    secretsManagement:
      provider: string          # kubernetes, vault, external-secrets
      encryption: bool          # Enable etcd encryption at rest

      # External secrets configuration
      externalSecrets:
        provider: string        # aws-secrets-manager, azure-keyvault, gcp-secret-manager
        config: map[string]string

    # Admission controllers
    admissionControllers:
      enabled: []string         # List of enabled admission controllers
      webhooks:
      - name: string
        endpoint: string
        rules: []string

    # Security scanning
    scanning:
      enabled: bool
      provider: string          # falco, twistlock, aqua
      schedule: string          # Scan schedule
```

#### Monitoring Configuration

```yaml
spec:
  monitoringConfig:
    # Prometheus configuration
    prometheus:
      enabled: bool
      version: string
      retention: string         # Data retention period (e.g., "30d")
      storageSize: string       # Storage size (e.g., "100Gi")

      # Prometheus settings
      config:
        scrapeInterval: string  # Default scrape interval
        evaluationInterval: string
        ruleFiles: []string

    # Grafana configuration
    grafana:
      enabled: bool
      version: string
      adminPassword: string

      # Grafana settings
      config:
        dashboards: []string    # List of dashboard URLs/configs
        datasources: []string   # Additional datasources
        plugins: []string       # Grafana plugins to install

    # Logging configuration
    logging:
      enabled: bool
      provider: string          # fluentd, fluentbit, loki, elasticsearch

      # Log aggregation settings
      aggregation:
        endpoint: string        # Log aggregation endpoint
        index: string          # Log index/database
        retention: string      # Log retention period

    # Alerting configuration
    alerting:
      enabled: bool
      provider: string          # alertmanager, pagerduty, slack

      # Alert routing
      routing:
        receivers:
        - name: string
          type: string          # email, slack, webhook, pagerduty
          config: map[string]string

      # Alert rules
      rules:
      - name: string
        expression: string      # PromQL expression
        duration: string        # Alert duration
        severity: string        # critical, warning, info

    # Metrics collection
    metrics:
      nodeExporter: bool        # Enable node exporter
      kubeStateMetrics: bool    # Enable kube-state-metrics
      cadvisor: bool           # Enable cAdvisor

      # Custom metrics
      customMetrics:
        enabled: bool
        adapters: []string      # prometheus-adapter, custom-metrics-api

    # Distributed tracing
    tracing:
      enabled: bool
      provider: string          # jaeger, zipkin, opentelemetry
      samplingRate: string      # Sampling rate (e.g., "0.1")

      # Tracing configuration
      config:
        endpoint: string
        namespace: string
        retention: string
```

#### Backup and Operations

```yaml
spec:
  backupConfig:
    # Backup settings
    enabled: bool
    provider: string            # velero, kasten, portworx
    schedule: string           # Backup schedule (cron format)

    # Backup destinations
    destinations:
    - type: string             # s3, gcs, azure-blob, nfs
      bucket: string           # Storage bucket/container
      region: string           # Storage region
      credentials: string      # Secret reference for credentials

    # Backup policies
    policies:
    - name: string
      namespaces: []string     # Namespaces to backup
      resources: []string      # Resource types to backup
      retention: string        # Backup retention period

  # Maintenance configuration
  maintenanceConfig:
    # Maintenance windows
    maintenanceWindows:
    - name: string
      schedule: string         # Cron schedule for maintenance
      duration: string         # Maintenance window duration
      timezone: string         # Timezone for schedule

    # Update policies
    updatePolicy:
      autoUpdate: bool         # Enable automatic updates
      channel: string          # stable, rapid, alpha
      schedule: string         # Update schedule

    # Node maintenance
    nodeMaintenance:
      drainTimeout: string     # Node drain timeout
      maxUnavailable: string   # Max unavailable nodes during maintenance

  # Disaster recovery
  disasterRecovery:
    enabled: bool

    # Cross-region replication
    replication:
      enabled: bool
      targetRegions: []string

    # Recovery procedures
    recovery:
      rpo: string             # Recovery Point Objective
      rto: string             # Recovery Time Objective
      procedures: []string    # Recovery procedure documents
```

### Status Fields

#### Cluster Status

```yaml
status:
  # Overall cluster state
  phase: string               # Provisioning, Ready, Updating, Error, Deleting

  # Detailed conditions
  conditions:
  - type: string             # Ready, Progressing, Available, etc.
    status: string           # True, False, Unknown
    lastTransitionTime: string
    reason: string
    message: string

  # Cluster information
  clusterInfo:
    endpoint: string         # Cluster API endpoint
    version: string         # Actual Kubernetes version
    platformVersion: string  # Provider platform version
    certificateAuthority: string

  # Node pool status
  nodePools:
  - name: string
    readyNodes: int32        # Number of ready nodes
    totalNodes: int32        # Total number of nodes
    conditions: []Condition

  # Cluster capacity and usage
  capacity:
    nodes: int32
    pods: int32
    services: int32

  usage:
    nodes: int32
    pods: int32
    services: int32
    cpu: string              # Total CPU usage
    memory: string           # Total memory usage
    storage: string          # Total storage usage

  # Networking status
  networking:
    cniReady: bool
    loadBalancerReady: bool
    ingressReady: bool
    serviceMeshReady: bool

  # Security status
  security:
    rbacEnabled: bool
    podSecurityEnabled: bool
    networkPoliciesEnabled: bool
    admissionControllersReady: bool

  # Monitoring status
  monitoring:
    prometheusReady: bool
    grafanaReady: bool
    loggingReady: bool
    alertingReady: bool

  # Backup status
  backup:
    lastBackupTime: string
    lastBackupStatus: string  # Success, Failed, InProgress
    nextScheduledBackup: string

  # Health metrics
  health:
    score: int32             # Overall health score 0-100
    lastChecked: string
    issues: []string         # List of current issues

  # Resource quotas and limits
  resources:
    quotas:
    - namespace: string
      hard: map[string]string
      used: map[string]string

  # Add-on status
  addons:
  - name: string
    version: string
    status: string           # Ready, NotReady, Error
    lastUpdated: string
```

## Validation Rules

### Required Fields

- `spec.type`: Must be one of the supported provider types
- `spec.version`: Must be a valid Kubernetes version
- `spec.clusterConfig.name`: Must be a valid cluster name
- `spec.nodePools`: At least one node pool must be defined

### Field Constraints

- `spec.version`: Must match semantic version pattern (e.g., "1.28.0")
- `spec.clusterConfig.networking.serviceCIDR`: Must be valid CIDR notation
- `spec.clusterConfig.networking.podCIDR`: Must be valid CIDR notation
- `spec.nodePools[].scaling.minNodes`: Must be ≥ 0
- `spec.nodePools[].scaling.maxNodes`: Must be ≥ minNodes
- `spec.monitoringConfig.tracing.samplingRate`: Must match decimal string pattern
- Timeout fields: Must match duration format (e.g., "30s", "5m")

### Provider-Specific Validations

- **EKS**: Requires valid VPC and subnet configurations
- **AKS**: Requires valid resource group and subscription
- **GKE**: Requires valid project ID and network configuration
- **RKE2**: Validates custom cluster configuration parameters

## Examples

### Amazon EKS Cluster

```yaml
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: production-eks
  namespace: default
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2

  clusterConfig:
    name: production-cluster
    displayName: "Production EKS Cluster"
    description: "Main production Kubernetes cluster"

    highAvailability:
      enabled: true
      controlPlaneNodes: 3

    networking:
      serviceCIDR: "10.100.0.0/16"
      podCIDR: "192.168.0.0/16"
      dnsProvider: coredns

    containerRuntime: containerd

    addons:
      dashboard: true
      ingressController: true
      storageClasses: true
      networkPolicies: true

  nodePools:
    - name: system
      role: worker
      nodeConfig:
        instanceType: m5.large
        imageId: ami-0c02fb55956c7d316
        diskSize: 100Gi
        diskType: gp3

      scaling:
        minNodes: 2
        maxNodes: 10
        desiredNodes: 3
        autoScaling:
          enabled: true
          scaleUpCooldown: 5m
          scaleDownCooldown: 10m
          cpuThreshold: "80.0"
          memoryThreshold: "80.0"

      placement:
        availabilityZones:
          - us-west-2a
          - us-west-2b
          - us-west-2c
        labels:
          node-type: system

    - name: compute
      role: worker
      nodeConfig:
        instanceType: c5.2xlarge
        imageId: ami-0c02fb55956c7d316
        diskSize: 200Gi
        diskType: gp3

      scaling:
        minNodes: 1
        maxNodes: 20
        desiredNodes: 5
        autoScaling:
          enabled: true
          cpuThreshold: "70.0"

      placement:
        availabilityZones:
          - us-west-2a
          - us-west-2b
        labels:
          node-type: compute

  networkConfig:
    cni: aws-vpc-cni
    cniConfig:
      version: "1.12.0"

    loadBalancer:
      type: cloud
      enabled: true
      cloudLB:
        scheme: internet-facing
        ipAddressType: ipv4

    ingress:
      enabled: true
      controller: aws-load-balancer-controller

  securityConfig:
    rbac:
      enabled: true
      strictMode: true

    podSecurity:
      podSecurityStandard: baseline
      enforce: true
      audit: true

    networkSecurity:
      networkPolicies: true

    secretsManagement:
      provider: aws-secrets-manager
      encryption: true

  monitoringConfig:
    prometheus:
      enabled: true
      version: "2.45.0"
      retention: 30d
      storageSize: 100Gi

    grafana:
      enabled: true
      version: "10.0.0"

    logging:
      enabled: true
      provider: fluentbit
      aggregation:
        endpoint: cloudwatch
        retention: 90d

    alerting:
      enabled: true
      provider: alertmanager

  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 2 * * *" # Daily at 2 AM
    destinations:
      - type: s3
        bucket: eks-cluster-backups
        region: us-west-2
```

### Rancher RKE2 On-Premises Cluster

```yaml
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: onprem-rke2
  namespace: default
spec:
  type: rke2
  version: "1.28.2+rke2r1"
  region: datacenter1

  clusterConfig:
    name: onprem-cluster
    displayName: "On-Premises RKE2 Cluster"
    description: "Production on-premises cluster"

    highAvailability:
      enabled: true
      controlPlaneNodes: 3

    networking:
      serviceCIDR: "10.43.0.0/16"
      podCIDR: "10.42.0.0/16"
      clusterDNS: "10.43.0.10"
      dnsProvider: coredns

    containerRuntime: containerd

    customConfig:
      cluster-cidr: "10.42.0.0/16"
      service-cidr: "10.43.0.0/16"
      disable-components: "rke2-ingress-nginx"

  nodePools:
    - name: masters
      role: master
      nodeConfig:
        instanceType: master-large # Custom instance type
        diskSize: 200Gi
        diskType: ssd

      scaling:
        minNodes: 3
        maxNodes: 3
        desiredNodes: 3

      nodeOptions:
        kubeletArgs:
          max-pods: "250"
        taints:
          - "node-role.kubernetes.io/control-plane:NoSchedule"

    - name: workers
      role: worker
      nodeConfig:
        instanceType: worker-large
        diskSize: 500Gi
        diskType: ssd

      scaling:
        minNodes: 3
        maxNodes: 10
        desiredNodes: 5

      nodeOptions:
        kubeletArgs:
          max-pods: "250"
        labels:
          node-type: worker

  networkConfig:
    cni: calico
    cniConfig:
      version: "3.26.0"
      customConfig:
        calico_backend: bird

    loadBalancer:
      type: metallb
      enabled: true
      metallb:
        addressPools:
          - name: default
            addresses:
              - "192.168.1.100-192.168.1.200"
            protocol: layer2

    ingress:
      enabled: true
      controller: traefik
      controllerConfig:
        replicas: 3

  securityConfig:
    rbac:
      enabled: true
      strictMode: true

    podSecurity:
      podSecurityStandard: restricted
      enforce: true

    networkSecurity:
      networkPolicies: true
      defaultDenyAll: true

    secretsManagement:
      provider: kubernetes
      encryption: true

  monitoringConfig:
    prometheus:
      enabled: true
      version: "2.45.0"
      retention: 90d
      storageSize: 500Gi

    grafana:
      enabled: true
      version: "10.0.0"
      config:
        dashboards:
          - "kubernetes-cluster-monitoring"
          - "node-exporter-full"

    logging:
      enabled: true
      provider: loki
      aggregation:
        retention: 30d

    metrics:
      nodeExporter: true
      kubeStateMetrics: true
      cadvisor: true

  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 3 * * *" # Daily at 3 AM
    destinations:
      - type: nfs
        bucket: /backup/k8s
        credentials: nfs-backup-credentials

  maintenanceConfig:
    maintenanceWindows:
      - name: weekly-maintenance
        schedule: "0 2 * * SUN" # Sunday 2 AM
        duration: 4h
        timezone: UTC

    updatePolicy:
      autoUpdate: false
      channel: stable
```

## Best Practices

1. **Cluster Planning**

   - Design for high availability with multiple control plane nodes
   - Plan network CIDR ranges to avoid conflicts
   - Size node pools based on workload requirements

2. **Security Hardening**

   - Enable RBAC and pod security standards
   - Implement network policies for micro-segmentation
   - Use external secrets management for sensitive data
   - Regular security scanning and updates

3. **Monitoring and Observability**

   - Deploy comprehensive monitoring stack
   - Set up centralized logging
   - Configure alerting for critical issues
   - Implement distributed tracing for complex applications

4. **Resource Management**

   - Set appropriate resource quotas and limits
   - Configure auto-scaling policies
   - Monitor resource utilization trends
   - Plan for capacity growth

5. **Backup and Recovery**
   - Implement regular backup schedules
   - Test recovery procedures regularly
   - Document disaster recovery plans
   - Consider cross-region replication for critical clusters

## Troubleshooting

### Common Issues

1. **Cluster Provisioning Failures**

   - Check provider authentication and permissions
   - Verify network configuration and connectivity
   - Review resource quotas and limits

2. **Node Join Failures**

   - Verify node security groups and network access
   - Check node image compatibility
   - Review kubelet logs and configuration

3. **Networking Issues**

   - Validate CNI configuration and compatibility
   - Check service and pod CIDR conflicts
   - Verify load balancer and ingress controller setup

4. **Storage Problems**
   - Check storage class configurations
   - Verify persistent volume provisioning
   - Review CSI driver installation and configuration

### Debugging Commands

```bash
# Check provider status
kubectl get kubernetesprovider -o wide

# Describe provider details
kubectl describe kubernetesprovider <provider-name>

# Check node status
kubectl get nodes -o wide

# Review cluster events
kubectl get events --sort-by=.metadata.creationTimestamp

# Check system pod status
kubectl get pods -n kube-system

# Validate cluster configuration
kubectl cluster-info
kubectl get componentstatuses
```

This documentation provides comprehensive guidance for deploying and managing Kubernetes clusters across different providers using the KubernetesProvider CRD.

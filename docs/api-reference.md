# VitiStack API Reference

## Overview

VitiStack provides a comprehensive set of Kubernetes Custom Resource Definitions (CRDs) for managing infrastructure across multiple cloud providers and on-premises environments. This API reference provides detailed information about all available resources, their fields, relationships, and usage patterns.

## API Groups and Versions

| API Group | Version | Stability | Description |
|-----------|---------|-----------|-------------|
| `vitistack.io` | `v1alpha1` | Alpha | Core infrastructure management resources |

## Resource Types

### Core Resources

| Resource | Kind | Scope | Description |
|----------|------|-------|-------------|
| datacenters | Datacenter | Namespaced | Logical datacenter or infrastructure region |
| machineproviders | MachineProvider | Namespaced | Compute instance provisioning configuration |
| kubernetesproviders | KubernetesProvider | Namespaced | Kubernetes cluster management configuration |
| machines | Machine | Namespaced | Individual compute instance specification |

## Common Fields

All VitiStack resources share common metadata and status patterns:

### Standard Metadata

```yaml
metadata:
  name: string          # Resource name (required)
  namespace: string     # Kubernetes namespace (required for namespaced resources)
  labels: {}           # Key-value labels for organization
  annotations: {}      # Additional metadata
  generation: int      # Resource generation number
  resourceVersion: string  # Resource version for optimistic concurrency
```

### Standard Status

```yaml
status:
  phase: string        # Current phase (Pending, Ready, Failed, etc.)
  conditions:          # Detailed status conditions
    - type: string     # Condition type
      status: string   # True, False, or Unknown
      reason: string   # Machine-readable reason
      message: string  # Human-readable message
      lastTransitionTime: timestamp
  observedGeneration: int  # Last processed generation
```

## Resource Specifications

### Datacenter

Represents a logical datacenter or infrastructure region that coordinates multiple providers and resources.

#### Full API Specification

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: string                    # Required: Datacenter name
  namespace: string               # Required: Kubernetes namespace
spec:
  # Basic Configuration
  region: string                  # Required: Geographical region
  description: string             # Optional: Human-readable description
  
  # Networking Configuration
  networking:
    vpcs:                        # VPC configurations
      - name: string             # VPC name
        cidr: string             # CIDR block (e.g., "10.0.0.0/16")
        region: string           # Region for this VPC
        subnets:                 # Subnet configurations
          - name: string         # Subnet name
            cidr: string         # Subnet CIDR
            type: string         # public, private, or database
            availabilityZone: string
            tags: {}             # Additional tags
        tags: {}                 # VPC tags
    
    loadBalancers:               # Load balancer configurations
      - name: string             # Load balancer name
        type: string             # application, network, or classic
        scheme: string           # internet-facing or internal
        internal: boolean        # Internal load balancer
        listeners:               # Listener configurations
          - port: integer        # Listener port
            protocol: string     # HTTP, HTTPS, TCP, or UDP
            certificateArn: string  # SSL certificate ARN
        healthCheck:             # Health check configuration
          path: string           # Health check path
          port: integer          # Health check port
          protocol: string       # Health check protocol
          interval: integer      # Check interval in seconds
    
    firewallRules:               # Firewall rule configurations
      - name: string             # Rule name
        direction: string        # inbound or outbound
        protocol: string         # tcp, udp, icmp, or all
        port: integer            # Single port number
        ports: string            # Port range (e.g., "80-443")
        source: string           # Source CIDR or security group
        destination: string      # Destination CIDR or security group
        action: string           # allow or deny
        priority: integer        # Rule priority
    
    dns:                         # DNS configuration
      enabled: boolean           # Enable DNS management
      zone: string               # DNS zone name
      records:                   # DNS records
        - name: string           # Record name
          type: string           # A, AAAA, CNAME, MX, etc.
          value: string          # Record value
          ttl: integer           # Time to live
  
  # Security Configuration
  security:
    encryption:
      atRest: boolean            # Enable encryption at rest
      inTransit: boolean         # Enable encryption in transit
      kmsKeyId: string           # KMS key ID for encryption
    
    rbac:
      enabled: boolean           # Enable RBAC
      adminUsers: []string       # List of admin users
      adminGroups: []string      # List of admin groups
      readOnlyUsers: []string    # List of read-only users
      customRoles:               # Custom RBAC roles
        - name: string           # Role name
          permissions: []string  # List of permissions
          users: []string        # Users with this role
          groups: []string       # Groups with this role
    
    auditLogging:
      enabled: boolean           # Enable audit logging
      retention: string          # Log retention period (e.g., "90d")
      destination: string        # Log destination (cloudwatch, s3, etc.)
      config: {}                 # Provider-specific config
    
    compliance:
      frameworks: []string       # Compliance frameworks (SOC2, GDPR, etc.)
      scanning:
        enabled: boolean         # Enable compliance scanning
        schedule: string         # Scanning schedule (cron format)
        severity: string         # Minimum severity to report
  
  # Resource Management
  resourceQuotas:
    maxMachines: integer         # Maximum number of machines
    maxClusters: integer         # Maximum number of clusters
    maxProviders: integer        # Maximum number of providers
    maxCPU: string               # Maximum CPU allocation
    maxMemory: string            # Maximum memory allocation
    maxStorage: string           # Maximum storage allocation
    maxNetworkBandwidth: string  # Maximum network bandwidth
  
  # Provider References
  machineProviders:              # Referenced machine providers
    - name: string               # Provider name
      namespace: string          # Provider namespace
      priority: integer          # Provider priority (1 = highest)
      weight: integer            # Traffic weight for load balancing
      conditions:                # Conditions for using this provider
        - type: string           # Condition type
          operator: string       # eq, ne, gt, lt, etc.
          value: string          # Condition value
  
  kubernetesProviders:           # Referenced Kubernetes providers
    - name: string               # Provider name
      namespace: string          # Provider namespace
      priority: integer          # Provider priority
      weight: integer            # Traffic weight
      conditions: []             # Usage conditions
  
  # High Availability
  highAvailability:
    enabled: boolean             # Enable HA configuration
    replicationFactor: integer   # Number of replicas
    crossZone: boolean           # Cross-availability zone deployment
    crossRegion: boolean         # Cross-region deployment
    backupSchedule: string       # Backup schedule (cron format)
  
  # Disaster Recovery
  disasterRecovery:
    enabled: boolean             # Enable DR configuration
    replicationTargets:          # DR replication targets
      - name: string             # Target datacenter name
        namespace: string        # Target namespace
        region: string           # Target region
        provider: string         # Target provider
        replicationMode: string  # sync, async, or snapshot
        rpo: string              # Recovery Point Objective
        rto: string              # Recovery Time Objective
        schedule: string         # Replication schedule
  
  # Monitoring and Observability
  monitoring:
    enabled: boolean             # Enable monitoring
    provider: string             # Monitoring provider (prometheus, datadog, etc.)
    retention: string            # Metrics retention period
    exporters: []string          # List of metric exporters
    dashboards:                  # Dashboard configurations
      - name: string             # Dashboard name
        source: string           # Dashboard source (configmap, url, etc.)
        config: {}               # Dashboard-specific config
    alerting:                    # Alerting configuration
      enabled: boolean           # Enable alerting
      rules:                     # Alert rules
        - name: string           # Alert name
          expression: string     # PromQL expression
          severity: string       # Alert severity
          labels: {}             # Additional labels
          annotations: {}        # Alert annotations
  
  # Logging
  logging:
    enabled: boolean             # Enable centralized logging
    provider: string             # Logging provider (elasticsearch, splunk, etc.)
    retention: string            # Log retention period
    aggregation:                 # Log aggregation settings
      enabled: boolean           # Enable log aggregation
      filters: []string          # Log filters
      forwarding:                # Log forwarding rules
        - destination: string    # Forwarding destination
          filter: string         # Log filter expression
          format: string         # Log format
  
  # Backup and Recovery
  backup:
    enabled: boolean             # Enable backups
    schedule: string             # Backup schedule (cron format)
    retention: string            # Backup retention period
    storage:                     # Backup storage configuration
      type: string               # Storage type (s3, gcs, azure, etc.)
      bucket: string             # Storage bucket/container
      region: string             # Storage region
      encryption: boolean        # Enable backup encryption
    excludes: []string           # Resources to exclude from backup
  
  # Edge Computing (if applicable)
  edge:
    enabled: boolean             # Enable edge computing features
    locations:                   # Edge location configurations
      - name: string             # Location name
        region: string           # Location region
        connectivity:            # Connectivity configuration
          type: string           # Connection type (satellite, fiber, etc.)
          bandwidth: string      # Available bandwidth
          latency: string        # Expected latency
        resources:               # Available resources
          maxMachines: integer   # Maximum machines at this location
          maxCPU: string         # Maximum CPU
          maxMemory: string      # Maximum memory
        autonomy:                # Autonomous operation settings
          enabled: boolean       # Enable autonomous operation
          offlineTimeout: string # Timeout for offline operation
          localDecisionMaking: boolean

status:
  # Standard Status Fields
  phase: string                  # Pending, Initializing, Ready, Failed, Deleting
  conditions:
    - type: string               # DatacenterReady, ProvidersReady, NetworkingReady, etc.
      status: string             # True, False, Unknown
      reason: string             # Machine-readable reason
      message: string            # Human-readable message
      lastTransitionTime: timestamp
  
  # Datacenter-Specific Status
  providers:                     # Provider status summary
    machines:                    # Machine provider status
      total: integer             # Total number of machine providers
      ready: integer             # Number of ready providers
      failed: integer            # Number of failed providers
    kubernetes:                  # Kubernetes provider status
      total: integer             # Total number of k8s providers
      ready: integer             # Number of ready providers
      failed: integer            # Number of failed providers
  
  resources:                     # Resource usage summary
    machines:
      total: integer             # Total machines
      running: integer           # Running machines
      pending: integer           # Pending machines
      failed: integer            # Failed machines
    clusters:
      total: integer             # Total clusters
      ready: integer             # Ready clusters
      pending: integer           # Pending clusters
    storage:
      allocated: string          # Allocated storage
      used: string               # Used storage
      available: string          # Available storage
  
  networking:                    # Networking status
    vpcs:                        # VPC status
      - name: string             # VPC name
        id: string               # VPC ID
        state: string            # VPC state
        cidr: string             # VPC CIDR
    loadBalancers:               # Load balancer status
      - name: string             # LB name
        arn: string              # LB ARN/ID
        dnsName: string          # LB DNS name
        state: string            # LB state
    firewalls:                   # Firewall status
      - name: string             # Firewall name
        id: string               # Firewall ID
        state: string            # Firewall state
  
  security:                      # Security status
    encryption:
      atRest: boolean            # Encryption at rest status
      inTransit: boolean         # Encryption in transit status
    compliance:
      frameworks: []string       # Active compliance frameworks
      lastScan: timestamp        # Last compliance scan
      status: string             # Compliance status
  
  monitoring:                    # Monitoring status
    enabled: boolean             # Monitoring enabled status
    endpoints:                   # Monitoring endpoints
      - name: string             # Endpoint name
        url: string              # Endpoint URL
        status: string           # Endpoint status
  
  backup:                        # Backup status
    enabled: boolean             # Backup enabled status
    lastBackup: timestamp        # Last backup time
    nextBackup: timestamp        # Next scheduled backup
    backupCount: integer         # Number of available backups
  
  # Timestamps
  creationTimestamp: timestamp   # Resource creation time
  lastUpdateTimestamp: timestamp # Last update time
  observedGeneration: integer    # Last observed generation
```

### MachineProvider

Defines how to provision and manage compute instances across different infrastructure providers.

#### Common Provider Types

| Provider Type | Description | Configuration Key |
|---------------|-------------|-------------------|
| `aws` | Amazon Web Services EC2 | `aws` |
| `azure` | Microsoft Azure Virtual Machines | `azure` |
| `gcp` | Google Cloud Platform Compute Engine | `gcp` |
| `vsphere` | VMware vSphere | `vsphere` |
| `openstack` | OpenStack Nova | `openstack` |
| `baremetal` | Bare Metal Servers | `baremetal` |

#### AWS Provider Configuration

```yaml
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: aws-provider
spec:
  type: aws
  region: us-west-2
  
  aws:
    # Authentication
    credentials:
      secretRef:
        name: aws-credentials    # Secret containing AWS credentials
        namespace: default       # Secret namespace
      # Alternative: Use IAM roles for service accounts (IRSA)
      serviceAccount: aws-machine-provider
    
    # Instance Configuration
    instanceTypes:
      - name: t3.micro          # Instance type name
        vcpus: 1                # Number of vCPUs
        memory: 1Gi             # Memory allocation
        storage: 8Gi            # Root volume size
        networkPerformance: low # Network performance tier
        pricing:                # Pricing information
          onDemand: "$0.0104/hour"
          spot: "$0.0031/hour"
          reserved1Year: "$0.0062/hour"
          reserved3Year: "$0.0042/hour"
        availability:           # Availability information
          regions: ["us-west-2", "us-east-1"]
          zones: ["us-west-2a", "us-west-2b"]
    
    # Machine Images (AMIs)
    machineImages:
      - name: ubuntu-20.04      # Image name
        imageId: ami-0c55b159cbfafe1d0  # AMI ID
        architecture: x86_64    # Architecture (x86_64, arm64)
        operatingSystem: ubuntu # OS type
        version: "20.04"        # OS version
        description: "Ubuntu 20.04 LTS"
        public: true            # Public AMI
        encrypted: false        # Encrypted AMI
        tags:                   # Image tags
          Environment: production
          OS: ubuntu
    
    # Networking
    networking:
      vpcId: vpc-12345678       # VPC ID (optional, can be managed by Datacenter)
      subnets:                  # Subnet IDs
        - subnet-12345678
        - subnet-87654321
      securityGroups:           # Security group configurations
        - name: web-servers     # Security group name
          description: "Web server security group"
          rules:                # Security group rules
            - type: ingress     # ingress or egress
              protocol: tcp     # tcp, udp, icmp, or all
              fromPort: 80      # Start port
              toPort: 80        # End port
              source: "0.0.0.0/0"  # Source CIDR
            - type: ingress
              protocol: tcp
              fromPort: 443
              toPort: 443
              source: "0.0.0.0/0"
            - type: ingress
              protocol: tcp
              fromPort: 22
              toPort: 22
              source: "10.0.0.0/8"  # Private network access only
    
    # Storage Configuration
    storage:
      defaultVolumeType: gp3    # Default EBS volume type
      defaultVolumeSize: 20Gi   # Default volume size
      encryption: true          # Enable encryption
      kmsKeyId: "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      iops: 3000               # Provisioned IOPS (for io1/io2)
      throughput: 125          # Throughput in MB/s (for gp3)
      
      # Additional volumes
      additionalVolumes:
        - name: data-volume     # Volume name
          size: 100Gi           # Volume size
          type: gp3             # Volume type
          mountPath: /data      # Mount path
          encryption: true      # Enable encryption
    
    # Auto Scaling
    autoScaling:
      enabled: true             # Enable auto scaling
      minSize: 1                # Minimum instances
      maxSize: 10               # Maximum instances
      desiredCapacity: 3        # Desired capacity
      targetCPUUtilization: 70  # Target CPU utilization %
      targetMemoryUtilization: 80  # Target memory utilization %
      scaleUpCooldown: 300      # Scale up cooldown (seconds)
      scaleDownCooldown: 300    # Scale down cooldown (seconds)
      
      # Custom metrics
      customMetrics:
        - name: custom-metric   # Metric name
          targetValue: 50       # Target value
          scaleUpThreshold: 80  # Scale up threshold
          scaleDownThreshold: 20  # Scale down threshold
    
    # Spot Instances
    spot:
      enabled: true             # Enable spot instances
      maxPrice: "$0.05"         # Maximum spot price
      spotFleetRequestConfig:   # Spot fleet configuration
        targetCapacity: 5       # Target capacity
        allocationStrategy: lowestPrice  # Allocation strategy
        instanceInterruptionBehavior: terminate  # Interruption behavior
    
    # Placement Groups
    placementGroups:
      - name: cluster-group     # Placement group name
        strategy: cluster       # cluster, partition, or spread
        partitionCount: 2       # Number of partitions (for partition strategy)
    
    # User Data Script
    userData: |
      #!/bin/bash
      yum update -y
      yum install -y docker
      systemctl start docker
      systemctl enable docker
      usermod -a -G docker ec2-user
  
  # Health Check Configuration
  healthCheck:
    enabled: true               # Enable health checks
    interval: 30s               # Check interval
    timeout: 10s                # Check timeout
    retries: 3                  # Number of retries
    initialDelay: 60s           # Initial delay before first check
    
    # Health check methods
    methods:
      - type: tcp               # tcp, http, or command
        port: 22                # Port to check
      - type: http
        port: 80
        path: /health           # HTTP path
        expectedStatus: 200     # Expected HTTP status
  
  # Lifecycle Management
  lifecycle:
    preDelete:
      enabled: true             # Enable pre-delete hooks
      drainTimeout: 600s        # Drain timeout
      gracePeriod: 30s          # Graceful shutdown period
      
    postCreate:
      enabled: true             # Enable post-create hooks
      scripts:                  # Post-create scripts
        - name: install-monitoring
          content: |
            #!/bin/bash
            # Install monitoring agent
            curl -sSL https://install.datadoghq.com/scripts/install_script.sh | bash
    
    updateStrategy:
      type: RollingUpdate       # RollingUpdate or Recreate
      maxUnavailable: 1         # Max unavailable during update
      maxSurge: 1               # Max surge during update
  
  # Tagging
  tags:
    Environment: production     # Environment tag
    Team: platform             # Team tag
    CostCenter: engineering    # Cost center tag
    Project: vitistack         # Project tag

status:
  phase: string                 # Pending, Ready, Failed, Updating
  conditions: []                # Status conditions
  
  # Provider-specific status
  instances:
    total: integer              # Total instances
    running: integer            # Running instances
    pending: integer            # Pending instances
    stopped: integer            # Stopped instances
    terminated: integer         # Terminated instances
  
  capacity:
    available: integer          # Available capacity
    used: integer               # Used capacity
    reserved: integer           # Reserved capacity
  
  costs:
    hourly: string              # Estimated hourly cost
    monthly: string             # Estimated monthly cost
    lastMonth: string           # Last month's actual cost
  
  regions:                      # Regional availability
    - name: string              # Region name
      available: boolean        # Region available
      instances: integer        # Instances in region
      capacity: integer         # Available capacity
  
  autoScaling:
    enabled: boolean            # Auto scaling status
    currentCapacity: integer    # Current capacity
    desiredCapacity: integer    # Desired capacity
    lastScaleUp: timestamp      # Last scale up time
    lastScaleDown: timestamp    # Last scale down time
```

### KubernetesProvider

Manages Kubernetes cluster lifecycle and configuration across different distributions.

#### Supported Distributions

| Distribution | Type | Configuration Key |
|--------------|------|-------------------|
| Amazon EKS | `eks` | `eks` |
| Azure AKS | `aks` | `aks` |
| Google GKE | `gke` | `gke` |
| Rancher RKE2 | `rke2` | `rke2` |
| Red Hat OpenShift | `openshift` | `openshift` |
| Vanilla Kubernetes | `vanilla` | `vanilla` |

#### EKS Provider Configuration

```yaml
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: eks-provider
spec:
  type: eks
  version: "1.24"
  region: us-west-2
  
  eks:
    # Authentication
    credentials:
      secretRef:
        name: aws-credentials
        namespace: default
    
    # Cluster Configuration
    clusterConfig:
      name: production-cluster  # Cluster name
      roleArn: "arn:aws:iam::123456789012:role/eks-service-role"
      
      # Network Configuration
      resourcesConfig:
        vpcConfig:
          subnetIds:            # Subnet IDs for cluster
            - subnet-12345678
            - subnet-87654321
          securityGroupIds:     # Security group IDs
            - sg-12345678
          endpointAccess:       # API endpoint access
            private: true       # Private endpoint access
            public: true        # Public endpoint access
            publicCIDRs:        # Public access CIDRs
              - "203.0.113.0/24"
      
      # Logging
      logging:
        enabled: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
      
      # Encryption
      encryption:
        enabled: true
        kmsKeyId: "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      
      # Tags
      tags:
        Environment: production
        Team: platform
    
    # Node Groups
    nodeGroups:
      - name: system-nodes      # Node group name
        instanceTypes:          # Instance types
          - m5.large
          - m5.xlarge
        amiType: AL2_x86_64     # AMI type
        capacityType: ON_DEMAND # ON_DEMAND or SPOT
        
        # Machine Provider Reference
        machineProvider:
          name: aws-provider    # Reference to MachineProvider
          namespace: default
        
        # Scaling Configuration
        scaling:
          minSize: 1            # Minimum nodes
          maxSize: 10           # Maximum nodes
          desiredSize: 3        # Desired nodes
        
        # Networking
        subnets:                # Subnet IDs for nodes
          - subnet-12345678
          - subnet-87654321
        
        # SSH Access
        remoteAccess:
          ec2SshKey: my-key-pair  # EC2 key pair name
          sourceSecurityGroups:   # Source security groups
            - sg-12345678
        
        # Kubernetes Labels and Taints
        labels:
          node-type: system     # Node labels
          environment: production
        
        taints:                 # Node taints
          - key: node-type
            value: system
            effect: NoSchedule
        
        # User Data
        userData: |
          #!/bin/bash
          /etc/eks/bootstrap.sh production-cluster
          
      - name: worker-nodes
        instanceTypes:
          - m5.xlarge
          - m5.2xlarge
        amiType: AL2_x86_64
        capacityType: SPOT
        scaling:
          minSize: 2
          maxSize: 20
          desiredSize: 5
        labels:
          node-type: worker
  
  # Networking Configuration
  networking:
    cni: aws-vpc-cni            # CNI plugin
    version: "1.11.4"           # CNI version
    
    # Service and Pod CIDRs
    serviceCIDR: "172.20.0.0/16"
    podCIDR: "10.244.0.0/16"
    
    # Network Policies
    networkPolicies:
      enabled: true             # Enable network policies
      provider: calico          # Network policy provider
      defaultDeny: true         # Default deny all traffic
    
    # Service Mesh
    serviceMesh:
      enabled: true             # Enable service mesh
      type: istio               # Service mesh type
      version: "1.15"           # Service mesh version
      config:                   # Service mesh configuration
        mtls:
          mode: STRICT          # mTLS mode
        tracing:
          enabled: true         # Enable tracing
          provider: jaeger      # Tracing provider
  
  # Security Configuration
  security:
    # RBAC
    rbac:
      enabled: true             # Enable RBAC
      
    # Pod Security Standards
    podSecurityStandards:
      enabled: true             # Enable Pod Security Standards
      policy: restricted        # baseline, restricted, or privileged
      auditMode: false          # Enable audit mode
      
    # Network Security
    networkSecurity:
      enabled: true             # Enable network security
      policies:                 # Network security policies
        - name: deny-all-default
          type: default-deny
          namespaces: ["default"]
        - name: allow-system-communication
          type: allow
          namespaces: ["kube-system", "istio-system"]
          ports: [80, 443, 8080]
    
    # Admission Controllers
    admissionControllers:
      - name: ImagePolicyWebhook  # Admission controller name
        enabled: true           # Enable admission controller
        config:                 # Controller configuration
          imagePolicy:
            allowedRegistries:  # Allowed container registries
              - "123456789012.dkr.ecr.us-west-2.amazonaws.com"
              - "gcr.io"
  
  # Add-ons Configuration
  addons:
    - name: aws-load-balancer-controller
      version: "v2.4.4"
      enabled: true
      config:
        clusterName: production-cluster
        serviceAccount:
          create: true
          name: aws-load-balancer-controller
          annotations:
            eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/AWSLoadBalancerControllerIAMRole"
    
    - name: cluster-autoscaler
      version: "1.24.0"
      enabled: true
      config:
        autoDiscovery:
          clusterName: production-cluster
        serviceAccount:
          annotations:
            eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/ClusterAutoscalerRole"
    
    - name: external-dns
      version: "0.12.2"
      enabled: true
      config:
        provider: aws
        domainFilters: ["example.com"]
        policy: upsert-only
        serviceAccount:
          annotations:
            eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/ExternalDNSRole"
    
    - name: cert-manager
      version: "v1.9.1"
      enabled: true
      config:
        installCRDs: true
        serviceAccount:
          annotations:
            eks.amazonaws.com/role-arn: "arn:aws:iam::123456789012:role/CertManagerRole"
    
    - name: prometheus-operator
      version: "0.60.1"
      enabled: true
      config:
        prometheus:
          retention: "15d"
          storage: "10Gi"
        grafana:
          enabled: true
          adminPassword:
            secretRef:
              name: grafana-admin
              key: password
  
  # Monitoring Configuration
  monitoring:
    enabled: true               # Enable monitoring
    
    # Prometheus Configuration
    prometheus:
      enabled: true             # Enable Prometheus
      retention: "15d"          # Metrics retention
      storage: "10Gi"           # Storage size
      resources:                # Resource requests/limits
        requests:
          cpu: "100m"
          memory: "512Mi"
        limits:
          cpu: "1000m"
          memory: "2Gi"
      
      # Service Monitor configurations
      serviceMonitors:
        - name: kubernetes-pods
          enabled: true
          selector:
            matchLabels:
              prometheus.io/scrape: "true"
    
    # Grafana Configuration
    grafana:
      enabled: true             # Enable Grafana
      adminPassword:
        secretRef:
          name: grafana-admin
          key: password
      dashboards:               # Dashboard configurations
        - name: kubernetes-cluster
          url: "https://grafana.com/api/dashboards/7249/revisions/1/download"
        - name: kubernetes-pods
          configMapRef:
            name: pod-dashboard
            key: dashboard.json
    
    # AlertManager Configuration
    alertmanager:
      enabled: true             # Enable AlertManager
      config:                   # AlertManager configuration
        global:
          slackApiUrl: "https://hooks.slack.com/services/xxx"
        receivers:
          - name: default-receiver
            slackConfigs:
              - channel: "#alerts"
                title: "Kubernetes Alert"
                text: "{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}"
        route:
          groupBy: ["alertname"]
          receiver: default-receiver
  
  # Backup Configuration
  backup:
    enabled: true               # Enable backups
    schedule: "0 2 * * *"       # Backup schedule (cron)
    retention: "30d"            # Backup retention
    
    # Backup storage
    storage:
      type: s3                  # Storage type
      bucket: "k8s-backups-production"  # S3 bucket
      region: us-west-2         # Storage region
      encryption: true          # Enable encryption
    
    # Backup configuration
    config:
      includeClusterResources: true  # Include cluster resources
      includedNamespaces:       # Namespaces to backup
        - default
        - kube-system
        - istio-system
      excludedResources:        # Resources to exclude
        - events
        - pods
      hooks:                    # Backup hooks
        - name: database-backup
          namespace: default
          includedResources:
            - persistentvolumeclaims
          pre:
            - exec:
                container: database
                command: ["pg_dump", "mydb"]
                onError: Continue

status:
  phase: string                 # Pending, Provisioning, Ready, Failed, Updating
  conditions: []                # Status conditions
  
  # Cluster Information
  cluster:
    name: string                # Cluster name
    endpoint: string            # API server endpoint
    version: string             # Kubernetes version
    status: string              # Cluster status
    
    # Certificate Authority
    certificateAuthority:
      data: string              # CA certificate data
    
    # OIDC Identity Provider
    identity:
      oidc:
        issuer: string          # OIDC issuer URL
    
    # Networking
    networking:
      serviceIPv4CIDR: string   # Service IPv4 CIDR
      podIPv4CIDR: string       # Pod IPv4 CIDR
  
  # Node Groups Status
  nodeGroups:
    - name: string              # Node group name
      status: string            # Node group status
      capacity:
        desired: integer        # Desired capacity
        current: integer        # Current capacity
        ready: integer          # Ready nodes
      instances:                # Instance information
        - id: string            # Instance ID
          status: string        # Instance status
          availability-zone: string  # AZ
  
  # Add-ons Status
  addons:
    - name: string              # Add-on name
      version: string           # Add-on version
      status: string            # Add-on status
      health: string            # Health status
  
  # Monitoring Status
  monitoring:
    prometheus:
      status: string            # Prometheus status
      endpoint: string          # Prometheus endpoint
    grafana:
      status: string            # Grafana status
      endpoint: string          # Grafana endpoint
    alertmanager:
      status: string            # AlertManager status
      endpoint: string          # AlertManager endpoint
  
  # Backup Status
  backup:
    lastBackup: timestamp       # Last backup time
    nextBackup: timestamp       # Next backup time
    backupCount: integer        # Number of backups
    status: string              # Backup status
```

### Machine

Represents individual compute instances that make up Kubernetes clusters or standalone workloads.

#### Full API Specification

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: string                  # Required: Machine name
  namespace: string             # Required: Kubernetes namespace
spec:
  # Provider Reference
  machineProvider:
    name: string                # Required: MachineProvider name
    namespace: string           # Provider namespace
  
  # Machine Specifications
  instanceType: string          # Instance type (e.g., m5.large)
  machineImage: string          # Machine image name
  
  # Networking Configuration
  networking:
    subnet: string              # Subnet ID or name
    subnetId: string            # Explicit subnet ID
    privateIP: string           # Static private IP (optional)
    publicIP: boolean           # Assign public IP
    
    # Security Groups
    securityGroups: []string    # Security group names/IDs
    
    # Elastic Network Interfaces
    networkInterfaces:
      - deviceIndex: integer    # Device index
        subnetId: string        # Subnet ID
        privateIP: string       # Private IP
        publicIP: boolean       # Public IP
        securityGroups: []string  # Security groups
        deleteOnTermination: boolean
  
  # Storage Configuration
  storage:
    # Root Volume
    rootVolume:
      size: string              # Volume size (e.g., "20Gi")
      type: string              # Volume type (gp3, io1, etc.)
      iops: integer             # Provisioned IOPS
      throughput: integer       # Throughput (MB/s)
      encryption: boolean       # Enable encryption
      kmsKeyId: string          # KMS key ID
      deleteOnTermination: boolean
    
    # Additional Volumes
    additionalVolumes:
      - name: string            # Volume name
        size: string            # Volume size
        type: string            # Volume type
        mountPath: string       # Mount path
        encryption: boolean     # Enable encryption
        iops: integer           # Provisioned IOPS
        tags: {}                # Volume tags
  
  # SSH Configuration
  sshKeys:
    - name: string              # Key name
      publicKey: string         # SSH public key
      keyPairName: string       # Cloud provider key pair name
  
  # Software Configuration
  software:
    # Package Installation
    packages:
      - name: string            # Package name
        version: string         # Package version
        source: string          # Package source (apt, yum, etc.)
    
    # Container Runtime
    containerRuntime:
      type: string              # docker, containerd, cri-o
      version: string           # Runtime version
      config: {}                # Runtime-specific configuration
    
    # Kubernetes Components
    kubernetes:
      version: string           # Kubernetes version
      role: string              # master, worker, or standalone
      components:               # Kubernetes components
        - name: string          # Component name
          version: string       # Component version
          config: {}            # Component configuration
    
    # Custom Scripts
    scripts:
      - name: string            # Script name
        content: string         # Script content
        order: integer          # Execution order
        runAsUser: string       # User to run script as
        environment: {}         # Environment variables
  
  # User Data / Cloud Init
  userData: string              # User data script
  cloudInit:                    # Cloud-init configuration
    users:                      # User creation
      - name: string            # Username
        groups: []string        # User groups
        shell: string           # User shell
        sshAuthorizedKeys: []string  # SSH keys
        sudo: string            # Sudo permissions
    
    packages: []string          # Packages to install
    
    writeFiles:                 # Files to write
      - path: string            # File path
        content: string         # File content
        permissions: string     # File permissions
        owner: string           # File owner
    
    runcmd: []string            # Commands to run
  
  # Placement Configuration
  placement:
    availabilityZone: string    # Specific AZ
    placementGroup: string      # Placement group name
    tenancy: string             # default, dedicated, or host
    hostId: string              # Dedicated host ID
    affinity:                   # Affinity rules
      nodeAffinity:             # Node affinity
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: string
                  operator: string
                  values: []string
    
    antiAffinity:               # Anti-affinity rules
      podAntiAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchLabels: {}
            topologyKey: string
  
  # Health Check Configuration
  healthCheck:
    enabled: boolean            # Enable health checks
    interval: string            # Check interval
    timeout: string             # Check timeout
    retries: integer            # Number of retries
    initialDelay: string        # Initial delay
    
    # Health check methods
    checks:
      - name: string            # Check name
        type: string            # tcp, http, command, or file
        config:                 # Check-specific configuration
          port: integer         # Port (for tcp/http)
          path: string          # Path (for http)
          command: []string     # Command (for command check)
          file: string          # File path (for file check)
          expectedStatus: integer  # Expected HTTP status
          expectedContent: string  # Expected content
  
  # Monitoring Configuration
  monitoring:
    enabled: boolean            # Enable monitoring
    agents:                     # Monitoring agents
      - name: string            # Agent name
        type: string            # Agent type (datadog, prometheus, etc.)
        config: {}              # Agent configuration
        version: string         # Agent version
    
    metrics:                    # Custom metrics
      - name: string            # Metric name
        type: string            # Metric type
        interval: string        # Collection interval
        config: {}              # Metric configuration
  
  # Backup Configuration
  backup:
    enabled: boolean            # Enable backups
    schedule: string            # Backup schedule
    retention: string           # Backup retention
    
    # Backup targets
    targets:
      - type: string            # snapshot, file, or database
        config: {}              # Target-specific configuration
        encryption: boolean     # Enable encryption
        compression: boolean    # Enable compression
  
  # Lifecycle Management
  lifecycle:
    # Pre-creation hooks
    preCreate:
      enabled: boolean          # Enable pre-create hooks
      scripts: []string         # Scripts to run
      timeout: string           # Hook timeout
    
    # Post-creation hooks  
    postCreate:
      enabled: boolean          # Enable post-create hooks
      scripts: []string         # Scripts to run
      timeout: string           # Hook timeout
    
    # Pre-deletion hooks
    preDelete:
      enabled: boolean          # Enable pre-delete hooks
      drainTimeout: string      # Drain timeout
      gracePeriod: string       # Grace period
      scripts: []string         # Scripts to run
    
    # Shutdown behavior
    shutdown:
      behavior: string          # stop or terminate
      timeout: string           # Shutdown timeout
  
  # Scheduling Configuration
  scheduling:
    priority: integer           # Scheduling priority
    schedulingPolicy: string    # Scheduling policy
    
    # Node selector
    nodeSelector: {}            # Node selector labels
    
    # Tolerations
    tolerations:
      - key: string             # Toleration key
        operator: string        # Equal or Exists
        value: string           # Toleration value
        effect: string          # NoSchedule, PreferNoSchedule, or NoExecute
        tolerationSeconds: integer
  
  # Security Configuration
  security:
    # Service Account
    serviceAccount:
      name: string              # Service account name
      create: boolean           # Create service account
      annotations: {}           # Service account annotations
    
    # Security Context
    securityContext:
      runAsUser: integer        # User ID
      runAsGroup: integer       # Group ID
      runAsNonRoot: boolean     # Run as non-root
      fsGroup: integer          # Filesystem group
      capabilities:             # Linux capabilities
        add: []string           # Capabilities to add
        drop: []string          # Capabilities to drop
    
    # Pod Security Policy
    podSecurityPolicy:
      name: string              # PSP name
      create: boolean           # Create PSP
      spec: {}                  # PSP specification
  
  # Resource Limits
  resources:
    requests:                   # Resource requests
      cpu: string               # CPU request
      memory: string            # Memory request
      storage: string           # Storage request
    limits:                     # Resource limits
      cpu: string               # CPU limit
      memory: string            # Memory limit
      storage: string           # Storage limit
  
  # Environment Variables
  environment:
    - name: string              # Environment variable name
      value: string             # Environment variable value
      valueFrom:                # Value from source
        secretKeyRef:           # From secret
          name: string          # Secret name
          key: string           # Secret key
        configMapKeyRef:        # From configmap
          name: string          # ConfigMap name
          key: string           # ConfigMap key
        fieldRef:               # From field
          fieldPath: string     # Field path
  
  # Labels and Annotations
  labels: {}                    # Machine labels
  annotations: {}               # Machine annotations
  
  # Tagging (for cloud resources)
  tags: {}                      # Cloud resource tags

status:
  # Standard Status
  phase: string                 # Pending, Provisioning, Running, Failed, Terminating
  conditions: []                # Status conditions
  
  # Machine Information
  machine:
    id: string                  # Machine/instance ID
    state: string               # Machine state
    launchTime: timestamp       # Launch time
    
    # Network Information
    networking:
      privateIP: string         # Private IP address
      publicIP: string          # Public IP address
      privateDNS: string        # Private DNS name
      publicDNS: string         # Public DNS name
      
      # Network Interfaces
      networkInterfaces:
        - id: string            # Interface ID
          privateIP: string     # Private IP
          publicIP: string      # Public IP
          macAddress: string    # MAC address
          subnetId: string      # Subnet ID
          vpcId: string         # VPC ID
    
    # Storage Information
    storage:
      rootVolume:
        id: string              # Volume ID
        size: string            # Volume size
        type: string            # Volume type
        state: string           # Volume state
      
      additionalVolumes:
        - id: string            # Volume ID
          name: string          # Volume name
          size: string          # Volume size
          mountPath: string     # Mount path
          state: string         # Volume state
    
    # Resource Usage
    resources:
      cpu:
        allocated: string       # Allocated CPU
        used: string            # Used CPU
        utilization: string     # CPU utilization %
      memory:
        allocated: string       # Allocated memory
        used: string            # Used memory
        utilization: string     # Memory utilization %
      storage:
        allocated: string       # Allocated storage
        used: string            # Used storage
        utilization: string     # Storage utilization %
  
  # Health Status
  health:
    overall: string             # Overall health status
    checks:                     # Individual health checks
      - name: string            # Check name
        status: string          # Check status
        message: string         # Check message
        lastCheck: timestamp    # Last check time
  
  # Software Status
  software:
    packages:                   # Installed packages
      - name: string            # Package name
        version: string         # Installed version
        status: string          # Installation status
    
    containerRuntime:
      type: string              # Runtime type
      version: string           # Runtime version
      status: string            # Runtime status
    
    kubernetes:
      version: string           # Kubernetes version
      role: string              # Node role
      status: string            # Kubernetes status
      components:               # Component status
        - name: string          # Component name
          version: string       # Component version
          status: string        # Component status
  
  # Monitoring Status
  monitoring:
    agents:                     # Monitoring agent status
      - name: string            # Agent name
        status: string          # Agent status
        lastReport: timestamp   # Last report time
    
    metrics:                    # Metrics collection status
      - name: string            # Metric name
        status: string          # Collection status
        lastCollection: timestamp
  
  # Backup Status
  backup:
    enabled: boolean            # Backup enabled
    lastBackup: timestamp       # Last backup time
    nextBackup: timestamp       # Next backup time
    backups:                    # Available backups
      - id: string              # Backup ID
        timestamp: timestamp    # Backup timestamp
        size: string            # Backup size
        status: string          # Backup status
  
  # Cost Information
  costs:
    hourly: string              # Hourly cost estimate
    daily: string               # Daily cost estimate
    monthly: string             # Monthly cost estimate
    currentMonth: string        # Current month cost
  
  # Events
  events:                       # Recent events
    - type: string              # Event type
      reason: string            # Event reason
      message: string           # Event message
      timestamp: timestamp      # Event timestamp
      count: integer            # Event count
```

## API Conventions

### Resource Naming

Follow Kubernetes naming conventions:
- Resource names must be DNS-1123 compliant
- Use lowercase letters, numbers, and hyphens
- Start and end with alphanumeric characters
- Maximum length of 253 characters

### Labels and Annotations

#### Standard Labels

| Label | Description | Example |
|-------|-------------|---------|
| `vitistack.io/environment` | Environment name | `production`, `staging`, `development` |
| `vitistack.io/region` | Geographical region | `us-west-2`, `eu-central-1` |
| `vitistack.io/team` | Owning team | `platform`, `backend`, `frontend` |
| `vitistack.io/version` | Resource version | `v1.0.0`, `v2.1.3` |
| `vitistack.io/component` | Component type | `database`, `api`, `worker` |

#### Standard Annotations

| Annotation | Description | Example |
|------------|-------------|---------|
| `vitistack.io/description` | Resource description | Human-readable description |
| `vitistack.io/contact` | Contact information | Email or team contact |
| `vitistack.io/documentation` | Documentation URL | Link to documentation |
| `vitistack.io/created-by` | Creation source | `kubectl`, `terraform`, `ci-cd` |

### Status Conditions

All resources use standard Kubernetes condition types:

| Type | Description | Status Values |
|------|-------------|---------------|
| `Ready` | Resource is ready for use | `True`, `False`, `Unknown` |
| `Available` | Resource is available | `True`, `False`, `Unknown` |
| `Progressing` | Resource is being updated | `True`, `False`, `Unknown` |
| `Failed` | Resource has failed | `True`, `False`, `Unknown` |

#### Custom Condition Types

| Resource | Condition Type | Description |
|----------|----------------|-------------|
| Datacenter | `ProvidersReady` | All referenced providers are ready |
| Datacenter | `NetworkingReady` | Networking configuration is complete |
| MachineProvider | `CredentialsValid` | Provider credentials are valid |
| MachineProvider | `CapacityAvailable` | Provider has available capacity |
| KubernetesProvider | `ClusterReady` | Kubernetes cluster is ready |
| KubernetesProvider | `AddonsReady` | All add-ons are installed and ready |
| Machine | `Provisioned` | Machine has been provisioned |
| Machine | `Configured` | Machine configuration is complete |

## Error Handling

### Common Error Codes

| Code | Description | Resolution |
|------|-------------|------------|
| `ProviderNotFound` | Referenced provider does not exist | Check provider name and namespace |
| `InsufficientCapacity` | Provider has insufficient capacity | Scale provider or use different provider |
| `AuthenticationFailed` | Provider authentication failed | Check credentials and permissions |
| `ValidationFailed` | Resource validation failed | Check resource specification |
| `DependencyNotReady` | Dependency resource is not ready | Wait for dependency or check its status |

### Error Response Format

```yaml
status:
  conditions:
    - type: "Failed"
      status: "True"
      reason: "ProviderNotFound"
      message: "MachineProvider 'aws-provider' not found in namespace 'default'"
      lastTransitionTime: "2023-10-01T12:00:00Z"
```

## Rate Limiting

API calls are subject to rate limiting to prevent abuse:

| Resource Type | Requests per Minute | Burst |
|---------------|-------------------|-------|
| Datacenter | 30 | 50 |
| MachineProvider | 60 | 100 |
| KubernetesProvider | 30 | 50 |
| Machine | 120 | 200 |

## Versioning and Compatibility

### API Versioning

- Current version: `v1alpha1`
- Planned stable version: `v1`
- Backward compatibility: Maintained for one major version

### Migration Path

When upgrading API versions:
1. Both versions are supported simultaneously
2. Automatic conversion between versions
3. Deprecation warnings for old versions
4. Migration guides provided

## Security Considerations

### Authentication

- All API calls require valid Kubernetes authentication
- Service accounts used for controllers require minimal permissions
- Cross-namespace access requires explicit RBAC configuration

### Authorization

- RBAC policies control access to CRD operations
- Fine-grained permissions available for different operations
- Audit logging tracks all API access

### Data Protection

- Sensitive data stored in Kubernetes Secrets
- Encryption at rest and in transit
- Secret rotation and management policies

This API reference provides comprehensive documentation for all VitiStack CRDs and their usage patterns. For specific implementation details and examples, refer to the individual CRD documentation and integration guides.

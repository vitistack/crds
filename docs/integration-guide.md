# VitiStack CRD Integration Guide

## Overview

This guide demonstrates how the four VitiStack CRDs work together to create a complete infrastructure management solution. We'll walk through real-world scenarios showing the relationships between Vitistack, MachineProvider, KubernetesProvider, and Machine resources.

## Integration Scenarios

### Scenario 1: Single Cloud Kubernetes Cluster

This scenario shows how to deploy a complete Kubernetes cluster on AWS using all four CRDs.

#### Step 1: Create the Vitistack

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: aws-production
  namespace: production
spec:
  region: us-west-2
  description: "Production vitistack in AWS US West 2"

  # Network Configuration
  networking:
    vpcs:
      - name: production-vpc
        cidr: "10.0.0.0/16"
        subnets:
          - name: public-subnet-1
            cidr: "10.0.1.0/24"
            type: public
            availabilityZone: us-west-2a
          - name: private-subnet-1
            cidr: "10.0.2.0/24"
            type: private
            availabilityZone: us-west-2a
          - name: private-subnet-2
            cidr: "10.0.3.0/24"
            type: private
            availabilityZone: us-west-2b

    loadBalancers:
      - name: k8s-api-lb
        type: network
        internal: false

    firewallRules:
      - name: k8s-api-access
        direction: inbound
        protocol: tcp
        port: 443
        source: "0.0.0.0/0"
      - name: ssh-access
        direction: inbound
        protocol: tcp
        port: 22
        source: "10.0.0.0/16"

  # Security Configuration
  security:
    encryption:
      atRest: true
      inTransit: true

    rbac:
      enabled: true
      adminGroups:
        - "aws-admins"
        - "k8s-admins"

    auditLogging:
      enabled: true
      retention: "90d"

  # Resource Quotas
  resourceQuotas:
    maxMachines: 100
    maxClusters: 5
    maxProviders: 10

  # Provider References
  machineProviders:
    - name: aws-ec2-provider
      priority: 1
      namespace: production

  kubernetesProviders:
    - name: aws-eks-provider
      priority: 1
      namespace: production

  # Monitoring & Backup
  monitoring:
    enabled: true
    provider: prometheus
    exporters:
      - node
      - cluster

  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention: "30d"
```

#### Step 2: Create the MachineProvider

```yaml
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: aws-ec2-provider
  namespace: production
spec:
  type: aws
  region: us-west-2

  # AWS-specific configuration
  aws:
    credentials:
      secretRef:
        name: aws-credentials
        namespace: production

    instanceTypes:
      - name: m5.large
        vcpus: 2
        memory: 8Gi
        storage: 20Gi
        networkPerformance: moderate
        pricing:
          onDemand: "$0.096/hour"
          spot: "$0.038/hour"

      - name: m5.xlarge
        vcpus: 4
        memory: 16Gi
        storage: 20Gi
        networkPerformance: high
        pricing:
          onDemand: "$0.192/hour"
          spot: "$0.076/hour"

    # Machine Images
    machineImages:
      - name: ubuntu-20.04
        imageId: ami-0c55b159cbfafe1d0
        architecture: x86_64
        operatingSystem: ubuntu
        version: "20.04"

      - name: amazon-linux-2
        imageId: ami-0c02fb55956c7d316
        architecture: x86_64
        operatingSystem: amazon-linux
        version: "2"

    # Networking
    networking:
      vpcId: "vpc-12345678" # Reference to VPC created by Vitistack
      subnets:
        - subnet-12345678 # private-subnet-1
        - subnet-87654321 # private-subnet-2
      securityGroups:
        - name: k8s-nodes
          rules:
            - protocol: tcp
              port: 22
              source: "10.0.0.0/16"
            - protocol: tcp
              ports: "30000-32767"
              source: "10.0.0.0/16"

    # Storage
    storage:
      defaultVolumeType: gp3
      defaultVolumeSize: 20Gi
      encryption: true

  # Health Monitoring
  healthCheck:
    enabled: true
    interval: 30s
    timeout: 10s
    retries: 3

  # Auto-scaling
  autoScaling:
    enabled: true
    minSize: 1
    maxSize: 10
    targetCPUUtilization: 70
    scaleUpCooldown: 5m
    scaleDownCooldown: 10m

  # Lifecycle Management
  lifecycle:
    preDelete:
      enabled: true
      drainTimeout: 10m

    updateStrategy:
      type: RollingUpdate
      maxUnavailable: 1
      maxSurge: 1
```

#### Step 3: Create the KubernetesProvider

```yaml
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: aws-eks-provider
  namespace: production
spec:
  type: eks
  version: "1.24"
  region: us-west-2

  # EKS-specific configuration
  eks:
    credentials:
      secretRef:
        name: aws-credentials
        namespace: production

    clusterConfig:
      endpointAccess:
        private: true
        public: true
        publicCIDRs:
          - "0.0.0.0/0"

      logging:
        enabled:
          ["api", "audit", "authenticator", "controllerManager", "scheduler"]

      encryption:
        enabled: true
        kmsKeyId: "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"

    # Node Groups
    nodeGroups:
      - name: system-nodes
        machineProvider:
          name: aws-ec2-provider
          namespace: production
        instanceType: m5.large
        amiType: AL2_x86_64
        capacityType: ON_DEMAND
        scaling:
          minSize: 2
          maxSize: 4
          desiredSize: 2
        subnets:
          - subnet-12345678
          - subnet-87654321
        labels:
          node-type: system
        taints:
          - key: node-type
            value: system
            effect: NoSchedule

      - name: worker-nodes
        machineProvider:
          name: aws-ec2-provider
          namespace: production
        instanceType: m5.xlarge
        amiType: AL2_x86_64
        capacityType: SPOT
        scaling:
          minSize: 1
          maxSize: 10
          desiredSize: 3
        subnets:
          - subnet-12345678
          - subnet-87654321
        labels:
          node-type: worker

  # Networking
  networking:
    cni: aws-vpc-cni
    serviceCIDR: "172.20.0.0/16"
    podCIDR: "10.244.0.0/16"

    # Network Policies
    networkPolicies:
      enabled: true
      defaultDeny: true

    # Service Mesh
    serviceMesh:
      enabled: true
      type: istio
      version: "1.15"

  # Security
  security:
    rbac:
      enabled: true

    podSecurityStandards:
      enabled: true
      policy: restricted

    networkSecurity:
      enabled: true
      policies:
        - name: deny-all-default
          type: default-deny
        - name: allow-system-communication
          type: allow
          namespaces: ["kube-system", "istio-system"]

  # Add-ons
  addons:
    - name: aws-load-balancer-controller
      version: "v2.4.4"
      enabled: true

    - name: cluster-autoscaler
      version: "1.24.0"
      enabled: true
      config:
        autoDiscovery:
          clusterName: aws-production-cluster

    - name: external-dns
      version: "0.12.2"
      enabled: true
      config:
        provider: aws
        domainFilters: ["example.com"]

    - name: cert-manager
      version: "v1.9.1"
      enabled: true
      config:
        installCRDs: true

  # Monitoring
  monitoring:
    enabled: true
    prometheus:
      enabled: true
      retention: "15d"
      storage: 10Gi

    grafana:
      enabled: true
      adminPassword:
        secretRef:
          name: grafana-admin
          key: password

    alertmanager:
      enabled: true
      config:
        receivers:
          - name: slack-notifications
            slackConfigs:
              - apiURL: https://hooks.slack.com/services/xxx
                channel: "#alerts"

  # Backup
  backup:
    enabled: true
    schedule: "0 1 * * *"
    retention: "7d"
    storage:
      type: s3
      bucket: "k8s-backups-production"
```

#### Step 4: Create Individual Machines (if needed)

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: bastion-host
  namespace: production
spec:
  # Reference to MachineProvider
  machineProvider:
    name: aws-ec2-provider
    namespace: production

  # Machine specifications
  instanceType: t3.micro
  machineImage: ubuntu-20.04

  # Networking
  networking:
    subnet: subnet-12345678 # public-subnet-1
    publicIP: true
    securityGroups:
      - bastion-sg

  # SSH Access
  sshKeys:
    - name: admin-key
      publicKey: "ssh-rsa AAAAB3NzaC1yc2EAAAA..."

  # Software Installation
  software:
    packages:
      - name: docker
        version: "20.10.*"
      - name: kubectl
        version: "1.24.*"
      - name: helm
        version: "3.9.*"

    scripts:
      - name: setup-monitoring
        content: |
          #!/bin/bash
          # Install monitoring agents
          curl -sSL https://install.datadoghq.com/scripts/install_script.sh | bash
          systemctl enable datadog-agent
          systemctl start datadog-agent

  # Labels and Annotations
  labels:
    environment: production
    role: bastion
    team: platform

  annotations:
    description: "Bastion host for secure access to production environment"
```

#### Step 5: Apply Resources in Order

```bash
# 1. Create the namespace
kubectl create namespace production

# 2. Create AWS credentials secret
kubectl create secret generic aws-credentials \
  --from-literal=access-key-id=AKIAIOSFODNN7EXAMPLE \
  --from-literal=secret-access-key=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY \
  --namespace=production

# 3. Apply resources in dependency order
kubectl apply -f vitistack.yaml
kubectl apply -f machine-provider.yaml
kubectl apply -f kubernetes-provider.yaml
kubectl apply -f machine.yaml
```

### Scenario 2: Multi-Cloud Disaster Recovery

This scenario demonstrates a multi-cloud setup with primary and secondary vitistacks.

#### Primary Vitistack (AWS)

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: primary-vitistack
  namespace: production
spec:
  region: us-west-2
  description: "Primary production vitistack"

  # Disaster Recovery Configuration
  disasterRecovery:
    enabled: true
    replicationTargets:
      - name: secondary-vitistack
        namespace: production
        region: us-east-1
        provider: aws
        replicationMode: async
        rpo: "1h" # Recovery Point Objective
        rto: "30m" # Recovery Time Objective

  # Primary providers
  machineProviders:
    - name: aws-west-provider
      priority: 1

  kubernetesProviders:
    - name: eks-west-provider
      priority: 1
```

#### Secondary Vitistack (Azure)

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: secondary-vitistack
  namespace: production
spec:
  region: east-us
  description: "Secondary vitistack for disaster recovery"

  # Mark as DR vitistack
  role: disaster-recovery

  # Reference to primary
  primaryVitistack:
    name: primary-vitistack
    namespace: production

  # Secondary providers
  machineProviders:
    - name: azure-east-provider
      priority: 1

  kubernetesProviders:
    - name: aks-east-provider
      priority: 1
```

### Scenario 3: Edge Computing Deployment

This scenario shows how to deploy edge computing resources with central management.

#### Central Management Vitistack

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: central-management
  namespace: edge-system
spec:
  region: central
  description: "Central management for edge deployments"

  # Edge management configuration
  edgeManagement:
    enabled: true
    edgeLocations:
      - name: edge-west
        region: us-west
        maxMachines: 10
        maxClusters: 2
      - name: edge-east
        region: us-east
        maxMachines: 10
        maxClusters: 2

  # Central monitoring and logging
  monitoring:
    enabled: true
    aggregateEdgeMetrics: true

  logging:
    enabled: true
    aggregateEdgeLogs: true
```

#### Edge Location Vitistack

```yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: edge-west
  namespace: edge-west
spec:
  region: us-west
  description: "Edge location in US West"

  # Mark as edge vitistack
  role: edge

  # Reference to central management
  managementVitistack:
    name: central-management
    namespace: edge-system

  # Resource constraints for edge
  resourceQuotas:
    maxMachines: 10
    maxClusters: 2
    maxCPU: "100"
    maxMemory: "200Gi"
    maxStorage: "1Ti"

  # Edge-specific configuration
  edge:
    connectivity:
      type: satellite
      bandwidth: "100Mbps"
      latency: "500ms"

    autonomy:
      enabled: true
      offlineTimeout: "1h"
      localDecisionMaking: true
```

## Integration Patterns

### 1. Provider Chaining

Chain providers for failover scenarios:

```yaml
# Primary provider
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: primary-provider
spec:
  type: aws
  # ... configuration

  # Failover configuration
  failover:
    enabled: true
    healthCheck:
      interval: 30s
      timeout: 10s
      failureThreshold: 3

    targets:
      - name: secondary-provider
        namespace: production
        priority: 2
        conditions:
          - type: ProviderHealthy
            status: "False"

---
# Secondary provider
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: secondary-provider
spec:
  type: azure
  # ... configuration
```

### 2. Cross-Vitistack Resource Sharing

Share resources across vitistacks:

```yaml
# Shared storage provider
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: shared-storage-provider
spec:
  type: aws
  # ... configuration

  # Make available to multiple vitistacks
  shareWith:
    - vitistack: primary-vitistack
      namespace: production
    - vitistack: secondary-vitistack
      namespace: production

  # Shared storage configuration
  storage:
    shared:
      enabled: true
      replication:
        crossRegion: true
        targets:
          - region: us-east-1
          - region: us-west-2
```

### 3. Hierarchical Management

Implement hierarchical resource management:

```yaml
# Parent vitistack
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: global-vitistack
spec:
  region: global
  description: "Global vitistack for centralized management"

  # Child vitistacks
  childVitistacks:
    - name: us-vitistack
      namespace: us-region
    - name: eu-vitistack
      namespace: eu-region
    - name: asia-vitistack
      namespace: asia-region

  # Global policies
  globalPolicies:
    security:
      enforceEncryption: true
      requireMFA: true

    compliance:
      frameworks:
        - SOC2
        - GDPR
        - HIPAA

    resourceLimits:
      globalMaxMachines: 1000
      globalMaxClusters: 50

---
# Child vitistack
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: us-vitistack
  namespace: us-region
spec:
  region: us
  description: "US regional vitistack"

  # Reference to parent
  parentVitistack:
    name: global-vitistack
    namespace: default

  # Inherit policies from parent
  inheritPolicies: true

  # Region-specific configuration
  resourceQuotas:
    maxMachines: 500
    maxClusters: 25
```

## Monitoring Integration

### Cross-Resource Monitoring

Monitor resources across all CRDs:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: vitistack-crds
spec:
  selector:
    matchLabels:
      app: vitistack-controller
  endpoints:
    - port: metrics
      interval: 30s
      path: /metrics

---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vitistack-alerts
spec:
  groups:
    - name: vitistack.rules
      rules:
        - alert: VitistackProviderDown
          expr: vitistack_vitistack_provider_status{status="ready"} == 0
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Vitistack provider is down"
            description: "Provider {{ $labels.provider }} in vitistack {{ $labels.vitistack }} has been down for more than 5 minutes"

    - name: machine.rules
      rules:
        - alert: MachineProvisioningFailed
          expr: increase(vitistack_machine_provisioning_failures_total[5m]) > 0
          labels:
            severity: warning
          annotations:
            summary: "Machine provisioning is failing"
            description: "{{ $value }} machine provisioning failures in the last 5 minutes"

    - name: kubernetes.rules
      rules:
        - alert: KubernetesClusterUnhealthy
          expr: vitistack_kubernetes_cluster_ready{status="ready"} == 0
          for: 10m
          labels:
            severity: critical
          annotations:
            summary: "Kubernetes cluster is unhealthy"
            description: "Cluster {{ $labels.cluster }} has been unhealthy for more than 10 minutes"
```

## Troubleshooting Integration Issues

### Common Integration Problems

1. **Provider Reference Errors**

   ```bash
   # Check provider references
   kubectl get vitistack vitistack-name -o yaml | grep -A 10 machineProviders
   kubectl get machineprovider provider-name -o yaml
   ```

2. **Cross-Namespace Reference Issues**

   ```bash
   # Check RBAC permissions
   kubectl auth can-i get machineproviders --as=system:serviceaccount:namespace:controller-name

   # Check if resources exist in target namespace
   kubectl get machineproviders -n target-namespace
   ```

3. **Credential and Secret Issues**

   ```bash
   # Verify secrets exist
   kubectl get secrets -n namespace-name

   # Check secret content (be careful with sensitive data)
   kubectl get secret secret-name -o yaml
   ```

4. **Network Connectivity Issues**

   ```bash
   # Test connectivity between components
   kubectl run test-pod --image=busybox -it --rm -- nslookup provider-service.namespace.svc.cluster.local

   # Check network policies
   kubectl get networkpolicies -A
   ```

### Debugging Commands

```bash
# Get status of all CRDs
kubectl get vitistacks,machineproviders,kubernetesproviders,machines -A

# Detailed resource inspection
kubectl describe vitistack vitistack-name
kubectl get vitistack vitistack-name -o yaml

# Check controller logs
kubectl logs -n vitistack-system deployment/vitistack-controller -f
kubectl logs -n vitistack-system deployment/machine-controller -f

# Validate resource relationships
kubectl get vitistack vitistack-name -o jsonpath='{.spec.machineProviders[*].name}'
kubectl get machineprovider provider-name -o jsonpath='{.status.conditions[*].type}'

# Check events
kubectl get events --sort-by='.lastTimestamp' -A | grep -i vitistack
```

## Best Practices for Integration

### 1. Resource Naming

Use consistent naming conventions across all resources:

```yaml
# Vitistack: {environment}-{region}-vitistack
name: production-us-west-vitistack

# Provider: {provider-type}-{region}-provider
name: aws-us-west-provider

# Machine: {role}-{environment}-{sequence}
name: worker-production-001
```

### 2. Namespace Organization

Organize resources using namespaces:

```bash
# Environment-based namespaces
production/
├── vitistack
├── machine-providers
├── kubernetes-providers
└── machines

staging/
├── vitistack
├── machine-providers
├── kubernetes-providers
└── machines
```

### 3. Label and Annotation Strategy

Use consistent labels and annotations:

```yaml
metadata:
  labels:
    vitistack.io/environment: production
    vitistack.io/region: us-west-2
    vitistack.io/team: platform
    vitistack.io/version: v1.0.0
  annotations:
    vitistack.io/description: "Production Kubernetes cluster"
    vitistack.io/contact: "platform-team@company.com"
    vitistack.io/documentation: "https://docs.company.com/k8s"
```

### 4. Configuration Management

Store configurations in Git repositories:

```bash
infrastructure/
├── vitistacks/
│   ├── production/
│   │   └── vitistack.yaml
│   └── staging/
│       └── vitistack.yaml
├── providers/
│   ├── machine-providers/
│   └── kubernetes-providers/
└── machines/
    ├── bastion-hosts/
    └── worker-nodes/
```

### 5. Testing Strategy

Test integrations thoroughly:

```bash
# Dry-run configurations
kubectl apply --dry-run=client -f vitistack.yaml

# Validate before applying
kubectl apply --validate=true -f provider.yaml

# Test in staging first
kubectl apply -f staging/ --wait=true

# Gradual rollout to production
kubectl apply -f production/ --wait=true
```

This integration guide provides comprehensive examples of how the VitiStack CRDs work together to create powerful infrastructure management capabilities. The scenarios demonstrate real-world usage patterns and best practices for deploying and managing complex infrastructure across multiple clouds and environments.

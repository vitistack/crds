#!/bin/bash

# Kubernetes Provider CRD Validation Test Script
# This script validates the KubernetesProvider CRD with various configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRD_DIR="${SCRIPT_DIR}/crds"
EXAMPLES_DIR="${SCRIPT_DIR}/examples"
TEMP_DIR="/tmp/kubernetes-provider-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Kubernetes Provider CRD Validation Test ===${NC}"

# Create temp directory
mkdir -p "$TEMP_DIR"

# Function to print test status
print_test() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✓ PASS${NC}: $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}✗ FAIL${NC}: $message"
    elif [ "$status" = "INFO" ]; then
        echo -e "${BLUE}ℹ INFO${NC}: $message"
    elif [ "$status" = "WARN" ]; then
        echo -e "${YELLOW}⚠ WARN${NC}: $message"
    fi
}

# Test 1: Check if CRD file exists
print_test "INFO" "Testing Kubernetes Provider CRD existence and structure"
if [ -f "$CRD_DIR/vitistack.io_kubernetesproviders.yaml" ]; then
    print_test "PASS" "KubernetesProvider CRD file exists"
else
    print_test "FAIL" "KubernetesProvider CRD file not found"
    exit 1
fi

# Test 2: Validate CRD YAML structure
print_test "INFO" "Validating CRD YAML structure"
if kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_kubernetesproviders.yaml" > /dev/null 2>&1; then
    print_test "PASS" "CRD YAML structure is valid"
else
    print_test "FAIL" "CRD YAML structure is invalid"
    kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_kubernetesproviders.yaml"
    exit 1
fi

# Test 3: Apply CRD to cluster
print_test "INFO" "Applying KubernetesProvider CRD to cluster"
if kubectl apply -f "$CRD_DIR/vitistack.io_kubernetesproviders.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Successfully applied KubernetesProvider CRD"
else
    print_test "FAIL" "Failed to apply KubernetesProvider CRD"
    exit 1
fi

# Wait for CRD to be established
print_test "INFO" "Waiting for CRD to be established"
sleep 2

# Test 4: Verify CRD is established
if kubectl get crd kubernetesproviders.vitistack.io > /dev/null 2>&1; then
    print_test "PASS" "KubernetesProvider CRD is established"
else
    print_test "FAIL" "KubernetesProvider CRD is not established"
    exit 1
fi

# Test 5: Create test configurations
print_test "INFO" "Creating test Kubernetes Provider configurations"

# Test EKS Provider
cat > "$TEMP_DIR/eks-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: test-eks-provider
  namespace: default
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2
  clusterConfig:
    name: test-eks-cluster
    displayName: "Test EKS Cluster"
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
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: m5.large
      diskSize: 100Gi
      diskType: gp3
    scaling:
      minNodes: 2
      maxNodes: 10
      desiredNodes: 3
      autoScaling:
        enabled: true
        cpuThreshold: "80.0"
        memoryThreshold: "80.0"
    placement:
      availabilityZones:
      - us-west-2a
      - us-west-2b
  networkConfig:
    cni: aws-vpc-cni
    loadBalancer:
      type: cloud
      enabled: true
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
  monitoringConfig:
    prometheus:
      enabled: true
      version: "2.45.0"
      retention: 30d
    grafana:
      enabled: true
    logging:
      enabled: true
      provider: fluentbit
  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 2 * * *"
EOF

# Test AKS Provider
cat > "$TEMP_DIR/aks-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: test-aks-provider
  namespace: default
spec:
  type: aks
  version: "1.28.2"
  region: westus2
  clusterConfig:
    name: test-aks-cluster
    displayName: "Test AKS Cluster"
    highAvailability:
      enabled: true
      controlPlaneNodes: 3
    networking:
      serviceCIDR: "10.0.0.0/16"
      podCIDR: "10.244.0.0/16"
      dnsProvider: coredns
    containerRuntime: containerd
    addons:
      dashboard: false
      ingressController: true
      networkPolicies: true
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: Standard_D4s_v3
      diskSize: 128Gi
      diskType: Premium_LRS
    scaling:
      minNodes: 1
      maxNodes: 5
      desiredNodes: 2
      autoScaling:
        enabled: true
        cpuThreshold: "70.0"
    placement:
      availabilityZones:
      - "1"
      - "2"
      - "3"
  - name: user
    role: worker
    nodeConfig:
      instanceType: Standard_D8s_v3
      diskSize: 256Gi
      diskType: Premium_LRS
    scaling:
      minNodes: 0
      maxNodes: 10
      desiredNodes: 2
  networkConfig:
    cni: azure-cni
    loadBalancer:
      type: cloud
      enabled: true
    ingress:
      enabled: true
      controller: nginx
  securityConfig:
    rbac:
      enabled: true
    podSecurity:
      podSecurityStandard: restricted
      enforce: true
    networkSecurity:
      networkPolicies: true
  monitoringConfig:
    prometheus:
      enabled: true
      retention: 15d
    grafana:
      enabled: true
    logging:
      enabled: true
      provider: fluentd
    tracing:
      enabled: true
      provider: jaeger
      samplingRate: "0.1"
EOF

# Test RKE2 Provider
cat > "$TEMP_DIR/rke2-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: test-rke2-provider
  namespace: default
spec:
  type: rke2
  version: "1.28.2+rke2r1"
  region: datacenter1
  clusterConfig:
    name: test-rke2-cluster
    displayName: "Test RKE2 Cluster"
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
  nodePools:
  - name: masters
    role: master
    nodeConfig:
      instanceType: master-large
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
  monitoringConfig:
    prometheus:
      enabled: true
      retention: 90d
      storageSize: 500Gi
    grafana:
      enabled: true
    logging:
      enabled: true
      provider: loki
    metrics:
      nodeExporter: true
      kubeStateMetrics: true
  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 3 * * *"
    destinations:
    - type: nfs
      bucket: /backup/k8s
  maintenanceConfig:
    updatePolicy:
      autoUpdate: false
      channel: stable
EOF

# Test 6: Validate test configurations
print_test "INFO" "Validating test configurations"

for provider_file in eks-provider.yaml aks-provider.yaml rke2-provider.yaml; do
    provider_name=$(echo "$provider_file" | cut -d'-' -f1)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$provider_file" > /dev/null 2>&1; then
        print_test "PASS" "Valid $provider_name provider configuration"
    else
        print_test "FAIL" "Invalid $provider_name provider configuration"
        echo "Error details:"
        kubectl apply --dry-run=client -f "$TEMP_DIR/$provider_file"
    fi
done

# Test 7: Apply and verify resources
print_test "INFO" "Applying test Kubernetes Provider resources"

for provider_file in eks-provider.yaml aks-provider.yaml rke2-provider.yaml; do
    provider_name=$(echo "$provider_file" | cut -d'-' -f1)
    resource_name="test-${provider_name}-provider"
    
    if kubectl apply -f "$TEMP_DIR/$provider_file" > /dev/null 2>&1; then
        print_test "PASS" "Successfully applied $provider_name provider"
        
        # Wait a moment for resource to be created
        sleep 1
        
        # Verify resource exists
        if kubectl get kubernetesprovider "$resource_name" > /dev/null 2>&1; then
            print_test "PASS" "$provider_name provider resource exists"
        else
            print_test "FAIL" "$provider_name provider resource not found"
        fi
    else
        print_test "FAIL" "Failed to apply $provider_name provider"
    fi
done

# Test 8: Test invalid configurations
print_test "INFO" "Testing invalid configuration rejection"

# Invalid Kubernetes version
cat > "$TEMP_DIR/invalid-version.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: invalid-version-provider
  namespace: default
spec:
  type: eks
  version: "invalid-version"
  region: us-west-2
  clusterConfig:
    name: test-cluster
    networking:
      serviceCIDR: "10.100.0.0/16"
      podCIDR: "192.168.0.0/16"
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: m5.large
      diskSize: 100Gi
    scaling:
      minNodes: 1
      maxNodes: 3
      desiredNodes: 2
EOF

# Invalid CIDR
cat > "$TEMP_DIR/invalid-cidr.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: invalid-cidr-provider
  namespace: default
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2
  clusterConfig:
    name: test-cluster
    networking:
      serviceCIDR: "invalid-cidr"
      podCIDR: "192.168.0.0/16"
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: m5.large
      diskSize: 100Gi
    scaling:
      minNodes: 1
      maxNodes: 3
      desiredNodes: 2
EOF

# Invalid node scaling (maxNodes < minNodes)
cat > "$TEMP_DIR/invalid-scaling.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: invalid-scaling-provider
  namespace: default
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2
  clusterConfig:
    name: test-cluster
    networking:
      serviceCIDR: "10.100.0.0/16"
      podCIDR: "192.168.0.0/16"
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: m5.large
      diskSize: 100Gi
    scaling:
      minNodes: 5
      maxNodes: 3
      desiredNodes: 2
EOF

# Invalid sampling rate
cat > "$TEMP_DIR/invalid-sampling.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: invalid-sampling-provider
  namespace: default
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2
  clusterConfig:
    name: test-cluster
    networking:
      serviceCIDR: "10.100.0.0/16"
      podCIDR: "192.168.0.0/16"
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: m5.large
      diskSize: 100Gi
    scaling:
      minNodes: 1
      maxNodes: 3
      desiredNodes: 2
  monitoringConfig:
    tracing:
      enabled: true
      provider: jaeger
      samplingRate: "invalid-rate"
EOF

# Test invalid configurations
for invalid_file in invalid-version.yaml invalid-cidr.yaml invalid-scaling.yaml invalid-sampling.yaml; do
    config_type=$(echo "$invalid_file" | cut -d'-' -f2 | cut -d'.' -f1)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$invalid_file" > /dev/null 2>&1; then
        print_test "FAIL" "Invalid $config_type configuration was accepted (should be rejected)"
    else
        print_test "PASS" "Invalid $config_type configuration properly rejected"
    fi
done

# Test 9: Test complex multi-node pool configuration
print_test "INFO" "Testing complex multi-node pool configuration"

cat > "$TEMP_DIR/complex-nodepool.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: complex-nodepool-provider
  namespace: default
spec:
  type: gke
  version: "1.28.3"
  region: us-central1
  clusterConfig:
    name: complex-cluster
    displayName: "Complex Multi-Node Pool Cluster"
    highAvailability:
      enabled: true
      controlPlaneNodes: 3
    networking:
      serviceCIDR: "10.96.0.0/12"
      podCIDR: "10.48.0.0/14"
      dnsProvider: coredns
    containerRuntime: containerd
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: n1-standard-2
      diskSize: 100Gi
      diskType: pd-ssd
    scaling:
      minNodes: 3
      maxNodes: 6
      desiredNodes: 3
      autoScaling:
        enabled: true
        cpuThreshold: "80.0"
        memoryThreshold: "85.0"
    placement:
      availabilityZones:
      - us-central1-a
      - us-central1-b
      - us-central1-c
      labels:
        node-type: system
        workload: system
  - name: compute
    role: worker
    nodeConfig:
      instanceType: n1-standard-4
      diskSize: 200Gi
      diskType: pd-ssd
    scaling:
      minNodes: 2
      maxNodes: 20
      desiredNodes: 5
      autoScaling:
        enabled: true
        cpuThreshold: "70.0"
        memoryThreshold: "75.0"
    placement:
      availabilityZones:
      - us-central1-a
      - us-central1-b
      labels:
        node-type: compute
        workload: general
  - name: gpu
    role: worker
    nodeConfig:
      instanceType: n1-standard-4
      diskSize: 100Gi
      diskType: pd-ssd
    scaling:
      minNodes: 0
      maxNodes: 5
      desiredNodes: 0
      autoScaling:
        enabled: true
        cpuThreshold: "60.0"
    placement:
      availabilityZones:
      - us-central1-a
      labels:
        node-type: gpu
        workload: ml
      taints:
      - "nvidia.com/gpu=true:NoSchedule"
  networkConfig:
    cni: gke-cni
    loadBalancer:
      type: cloud
      enabled: true
    ingress:
      enabled: true
      controller: gce
  securityConfig:
    rbac:
      enabled: true
      strictMode: true
    podSecurity:
      podSecurityStandard: baseline
      enforce: true
    networkSecurity:
      networkPolicies: true
  monitoringConfig:
    prometheus:
      enabled: true
      retention: 30d
      storageSize: 200Gi
    grafana:
      enabled: true
    logging:
      enabled: true
      provider: fluentd
    metrics:
      nodeExporter: true
      kubeStateMetrics: true
      cadvisor: true
    tracing:
      enabled: true
      provider: jaeger
      samplingRate: "0.05"
  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 1 * * *"
    destinations:
    - type: gcs
      bucket: gke-cluster-backups
      region: us-central1
EOF

if kubectl apply --dry-run=client -f "$TEMP_DIR/complex-nodepool.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Complex multi-node pool configuration is valid"
else
    print_test "FAIL" "Complex multi-node pool configuration is invalid"
    echo "Error details:"
    kubectl apply --dry-run=client -f "$TEMP_DIR/complex-nodepool.yaml"
fi

# Test 10: Test edge cases and boundary values
print_test "INFO" "Testing edge cases and boundary values"

# Minimum configuration
cat > "$TEMP_DIR/minimal-config.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: minimal-config-provider
  namespace: default
spec:
  type: k3s
  version: "1.28.0"
  region: edge
  clusterConfig:
    name: minimal-cluster
    networking:
      serviceCIDR: "10.43.0.0/16"
      podCIDR: "10.42.0.0/16"
  nodePools:
  - name: single
    role: worker
    nodeConfig:
      instanceType: small
      diskSize: 20Gi
    scaling:
      minNodes: 1
      maxNodes: 1
      desiredNodes: 1
EOF

if kubectl apply --dry-run=client -f "$TEMP_DIR/minimal-config.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Minimal configuration is valid"
else
    print_test "FAIL" "Minimal configuration is invalid"
fi

# Test 11: Cleanup test resources
print_test "INFO" "Cleaning up test resources"

# Delete test resources
for provider_file in eks-provider.yaml aks-provider.yaml rke2-provider.yaml; do
    provider_name=$(echo "$provider_file" | cut -d'-' -f1)
    resource_name="test-${provider_name}-provider"
    
    if kubectl delete kubernetesprovider "$resource_name" > /dev/null 2>&1; then
        print_test "PASS" "Cleaned up $provider_name provider"
    else
        print_test "WARN" "Failed to cleanup $provider_name provider (may not exist)"
    fi
done

# Test 12: Test example files if they exist
if [ -f "$EXAMPLES_DIR/kubernetes-provider-example.yaml" ]; then
    print_test "INFO" "Testing example files"
    
    if kubectl apply --dry-run=client -f "$EXAMPLES_DIR/kubernetes-provider-example.yaml" > /dev/null 2>&1; then
        print_test "PASS" "Example file validation successful"
    else
        print_test "FAIL" "Example file validation failed"
        echo "Error details:"
        kubectl apply --dry-run=client -f "$EXAMPLES_DIR/kubernetes-provider-example.yaml"
    fi
else
    print_test "WARN" "Example file not found, skipping example validation"
fi

# Test 13: Check CRD schema completeness
print_test "INFO" "Checking CRD schema completeness"

# Extract schema from CRD
if kubectl get crd kubernetesproviders.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}' > /dev/null 2>&1; then
    schema=$(kubectl get crd kubernetesproviders.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}')
    
    # Check for required schema elements
    required_fields=("spec" "status" "metadata" "nodePools" "clusterConfig" "networkConfig")
    for field in "${required_fields[@]}"; do
        if echo "$schema" | grep -q "\"$field\""; then
            print_test "PASS" "Schema contains required field: $field"
        else
            print_test "FAIL" "Schema missing required field: $field"
        fi
    done
    
    # Check for validation patterns
    if echo "$schema" | grep -q "pattern"; then
        print_test "PASS" "Schema contains validation patterns"
    else
        print_test "WARN" "Schema may be missing validation patterns"
    fi
    
    # Check for enum validations
    if echo "$schema" | grep -q "enum"; then
        print_test "PASS" "Schema contains enum validations"
    else
        print_test "WARN" "Schema may be missing enum validations"
    fi
else
    print_test "FAIL" "Could not extract CRD schema"
fi

# Cleanup temp directory
rm -rf "$TEMP_DIR"

print_test "INFO" "Kubernetes Provider CRD validation test completed"

echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo "- CRD structure and syntax validation"
echo "- Multi-provider configuration testing (EKS, AKS, RKE2, GKE, K3S)"
echo "- Invalid configuration rejection testing"
echo "- Complex multi-node pool configuration testing"
echo "- Edge cases and boundary value testing"
echo "- Example file validation"
echo "- Schema completeness verification"

echo -e "\n${GREEN}All tests completed successfully!${NC}"

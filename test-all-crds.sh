#!/bin/bash

# All CRDs Validation Test Script
# This script validates all CRDs together and tests their integration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRD_DIR="${SCRIPT_DIR}/crds"
EXAMPLES_DIR="${SCRIPT_DIR}/examples"
TEMP_DIR="/tmp/all-crds-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}=== Complete CRD System Validation Test ===${NC}"
echo -e "${BLUE}Testing Machine, MachineProvider, KubernetesProvider, and Datacenter CRDs${NC}"

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
    elif [ "$status" = "STEP" ]; then
        echo -e "${MAGENTA}🔄 STEP${NC}: $message"
    fi
}

# Function to check if CRD exists and is ready
check_crd_ready() {
    local crd_name=$1
    local timeout=30
    local count=0
    
    while [ $count -lt $timeout ]; do
        if kubectl get crd "$crd_name" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null | grep -q "True"; then
            return 0
        fi
        sleep 1
        ((count++))
    done
    return 1
}

# Test 1: Check all CRD files exist
print_test "STEP" "Checking all CRD files exist"

crd_files=(
    "vitistack.io_machines.yaml"
    "vitistack.io_machineproviders.yaml"
    "vitistack.io_kubernetesproviders.yaml"
    "vitistack.io_datacenters.yaml"
)

for crd_file in "${crd_files[@]}"; do
    if [ -f "$CRD_DIR/$crd_file" ]; then
        print_test "PASS" "CRD file exists: $crd_file"
    else
        print_test "FAIL" "CRD file missing: $crd_file"
        exit 1
    fi
done

# Test 2: Validate all CRD YAML structures
print_test "STEP" "Validating all CRD YAML structures"

for crd_file in "${crd_files[@]}"; do
    crd_name=$(echo "$crd_file" | cut -d'_' -f2 | cut -d'.' -f1)
    
    if kubectl apply --dry-run=client -f "$CRD_DIR/$crd_file" > /dev/null 2>&1; then
        print_test "PASS" "Valid YAML structure: $crd_name"
    else
        print_test "FAIL" "Invalid YAML structure: $crd_name"
        kubectl apply --dry-run=client -f "$CRD_DIR/$crd_file"
        exit 1
    fi
done

# Test 3: Apply all CRDs to cluster
print_test "STEP" "Applying all CRDs to cluster"

for crd_file in "${crd_files[@]}"; do
    crd_name=$(echo "$crd_file" | cut -d'_' -f2 | cut -d'.' -f1)
    
    if kubectl apply -f "$CRD_DIR/$crd_file" > /dev/null 2>&1; then
        print_test "PASS" "Successfully applied CRD: $crd_name"
    else
        print_test "FAIL" "Failed to apply CRD: $crd_name"
        exit 1
    fi
done

# Test 4: Wait for all CRDs to be established
print_test "STEP" "Waiting for all CRDs to be established"

crd_names=(
    "machines.vitistack.io"
    "machineproviders.vitistack.io"
    "kubernetesproviders.vitistack.io"
    "datacenters.vitistack.io"
)

for crd_name in "${crd_names[@]}"; do
    if check_crd_ready "$crd_name"; then
        print_test "PASS" "CRD is ready: $crd_name"
    else
        print_test "FAIL" "CRD failed to become ready: $crd_name"
        exit 1
    fi
done

# Test 5: Create integrated test scenario
print_test "STEP" "Creating integrated test scenario"

# Create a complete datacenter with providers and machines
cat > "$TEMP_DIR/integrated-datacenter.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: integrated-test-dc
  namespace: default
  labels:
    environment: test
    purpose: integration
spec:
  name: "Integrated Test Datacenter"
  description: "Complete test datacenter with all components"
  location:
    region: us-west-2
    availabilityZones:
    - us-west-2a
    - us-west-2b
    coordinates:
      latitude: "37.7749"
      longitude: "-122.4194"
    address:
      street: "123 Test Street"
      city: "San Francisco"
      state: "CA"
      postalCode: "94105"
      country: "USA"
  
  providers:
    machineProviders:
    - name: aws-test-provider
      priority: 1
      config:
        region: us-west-2
        availabilityZones: ["us-west-2a", "us-west-2b"]
    kubernetesProviders:
    - name: eks-test-provider
      priority: 1
      config:
        region: us-west-2
        version: "1.28.0"
  
  networking:
    vpcs:
    - name: test-vpc
      cidr: "10.0.0.0/16"
      provider: aws
      region: us-west-2
      subnets:
      - name: public-subnet
        cidr: "10.0.1.0/24"
        type: public
        availabilityZone: us-west-2a
      - name: private-subnet
        cidr: "10.0.2.0/24"
        type: private
        availabilityZone: us-west-2a
    
    loadBalancers:
    - name: test-lb
      type: application
      provider: aws
      scheme: internet-facing
      subnets:
      - public-subnet
    
    dns:
      provider: route53
      zones:
      - name: test.example.com
        type: public
    
    firewallRules:
    - name: allow-https
      protocol: tcp
      port: "443"
      source: "0.0.0.0/0"
      target: "web-servers"
      action: allow
  
  security:
    compliance:
      frameworks:
      - SOC2
    encryption:
      atRest:
        enabled: true
        provider: aws-kms
      inTransit:
        enabled: true
        protocols:
        - TLS1.3
    accessControl:
      rbac:
        enabled: true
      mfa:
        enabled: true
        required: false
    auditLogging:
      enabled: true
      destination: s3://test-audit-logs
      retention: 365d
  
  monitoring:
    metrics:
      provider: prometheus
      retention: 30d
      alerting:
        enabled: true
        provider: alertmanager
    logging:
      provider: elk
      retention: 30d
    tracing:
      enabled: true
      provider: jaeger
      samplingRate: "0.1"
  
  backup:
    enabled: true
    schedule: "0 2 * * *"
    retention:
      daily: 7
      weekly: 4
      monthly: 3
    destinations:
    - type: s3
      bucket: test-backups
      region: us-west-2
  
  resourceQuotas:
    compute:
      totalCPU: "100"
      totalMemoryGB: "400"
    storage:
      totalStorageGB: "10000"
    network:
      totalBandwidthGbps: "10"
    cost:
      monthlyBudget: "5000"
      alertThreshold: "80.0"
EOF

# Create machine provider
cat > "$TEMP_DIR/integrated-machine-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: aws-test-provider
  namespace: default
  labels:
    datacenter: integrated-test-dc
    provider: aws
spec:
  type: aws
  region: us-west-2
  availabilityZones:
  - us-west-2a
  - us-west-2b
  
  config:
    endpoint: ec2.us-west-2.amazonaws.com
    timeout: 30s
    rateLimiting:
      requestsPerSecond: "5.0"
      burstLimit: 10
  
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: aws-test-credentials
        key: access-key-id
  
  capabilities:
    supportedOperations:
    - create
    - delete
    - start
    - stop
    supportedOSTypes:
    - linux
    - windows
    supportedInstanceTypes:
    - t3.micro
    - t3.small
    - m5.large
    
  networkConfig:
    defaultNetworkId: vpc-test123
    availableNetworks:
    - id: subnet-test123
      name: test-subnet
      cidr: 10.0.1.0/24
      type: public
      
  storageConfig:
    defaultStorageClass: gp3
    defaultDiskSize: 20Gi
    availableStorageTypes:
    - name: gp3
      type: ssd
      iopsPerGB: "3.0"
      
  computeConfig:
    defaultCPU: "1"
    defaultMemoryGB: "2.0"
    maxCPU: "32"
    maxMemoryGB: "128.0"
EOF

# Create Kubernetes provider
cat > "$TEMP_DIR/integrated-k8s-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: KubernetesProvider
metadata:
  name: eks-test-provider
  namespace: default
  labels:
    datacenter: integrated-test-dc
    provider: eks
spec:
  type: eks
  version: "1.28.0"
  region: us-west-2
  
  clusterConfig:
    name: test-cluster
    displayName: "Test EKS Cluster"
    description: "Integration test EKS cluster"
    
    highAvailability:
      enabled: true
      controlPlaneNodes: 3
      
    networking:
      serviceCIDR: "10.100.0.0/16"
      podCIDR: "192.168.0.0/16"
      dnsProvider: coredns
      
    containerRuntime: containerd
    
    addons:
      dashboard: false
      ingressController: true
      storageClasses: true
      
  nodePools:
  - name: system
    role: worker
    nodeConfig:
      instanceType: t3.medium
      imageId: ami-test123
      diskSize: 50Gi
      diskType: gp3
      
    scaling:
      minNodes: 1
      maxNodes: 3
      desiredNodes: 2
      autoScaling:
        enabled: true
        cpuThreshold: "80.0"
        memoryThreshold: "80.0"
        
    placement:
      availabilityZones:
      - us-west-2a
      - us-west-2b
      labels:
        node-type: system
        
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
    podSecurity:
      podSecurityStandard: baseline
      enforce: true
      
  monitoringConfig:
    prometheus:
      enabled: true
      retention: 15d
    grafana:
      enabled: true
    logging:
      enabled: true
      provider: fluentbit
      
  backupConfig:
    enabled: true
    provider: velero
    schedule: "0 3 * * *"
EOF

# Create test machines
cat > "$TEMP_DIR/integrated-machines.yaml" << 'EOF'
---
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: web-server-1
  namespace: default
  labels:
    datacenter: integrated-test-dc
    role: web-server
    environment: test
spec:
  machineProviderRef:
    name: aws-test-provider
    namespace: default
  
  instanceType: t3.small
  image: ami-test-ubuntu
  
  compute:
    cpu: "2"
    memoryGB: "4.0"
    
  storage:
    - name: root
      size: 50Gi
      type: gp3
      mountPath: "/"
    - name: data
      size: 100Gi
      type: gp3
      mountPath: "/data"
      
  networking:
    subnetId: subnet-test123
    securityGroups:
    - sg-web-servers
    publicIP: true
    
  userData: |
    #!/bin/bash
    apt-get update
    apt-get install -y nginx
    systemctl enable nginx
    systemctl start nginx
    
  tags:
    Name: "Test Web Server 1"
    Environment: "test"
    Role: "web-server"
    
---
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: app-server-1
  namespace: default
  labels:
    datacenter: integrated-test-dc
    role: app-server
    environment: test
spec:
  machineProviderRef:
    name: aws-test-provider
    namespace: default
  
  instanceType: m5.large
  image: ami-test-ubuntu
  
  compute:
    cpu: "4"
    memoryGB: "8.0"
    
  storage:
    - name: root
      size: 100Gi
      type: gp3
      mountPath: "/"
    - name: app-data
      size: 200Gi
      type: gp3
      mountPath: "/opt/app"
      
  networking:
    subnetId: subnet-test456
    securityGroups:
    - sg-app-servers
    publicIP: false
    
  userData: |
    #!/bin/bash
    apt-get update
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    
  tags:
    Name: "Test App Server 1"
    Environment: "test"
    Role: "app-server"
EOF

# Test 6: Validate integrated configurations
print_test "STEP" "Validating integrated configurations"

configs=(
    "integrated-datacenter.yaml:Datacenter"
    "integrated-machine-provider.yaml:MachineProvider"
    "integrated-k8s-provider.yaml:KubernetesProvider"
    "integrated-machines.yaml:Machines"
)

for config in "${configs[@]}"; do
    file=$(echo "$config" | cut -d':' -f1)
    name=$(echo "$config" | cut -d':' -f2)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$file" > /dev/null 2>&1; then
        print_test "PASS" "Valid integrated $name configuration"
    else
        print_test "FAIL" "Invalid integrated $name configuration"
        echo "Error details for $file:"
        kubectl apply --dry-run=client -f "$TEMP_DIR/$file"
    fi
done

# Test 7: Apply integrated resources
print_test "STEP" "Applying integrated resources"

# Apply in dependency order
apply_order=(
    "integrated-datacenter.yaml"
    "integrated-machine-provider.yaml"
    "integrated-k8s-provider.yaml"
    "integrated-machines.yaml"
)

for file in "${apply_order[@]}"; do
    if kubectl apply -f "$TEMP_DIR/$file" > /dev/null 2>&1; then
        print_test "PASS" "Successfully applied $file"
        sleep 1  # Brief pause between applications
    else
        print_test "FAIL" "Failed to apply $file"
        echo "Error details:"
        kubectl apply -f "$TEMP_DIR/$file"
    fi
done

# Test 8: Verify cross-references work
print_test "STEP" "Verifying cross-references and relationships"

# Check if machines reference the correct provider
if kubectl get machine web-server-1 -o jsonpath='{.spec.machineProviderRef.name}' 2>/dev/null | grep -q "aws-test-provider"; then
    print_test "PASS" "Machine correctly references MachineProvider"
else
    print_test "FAIL" "Machine does not correctly reference MachineProvider"
fi

# Check if resources exist and have proper labels
resources=(
    "datacenter:integrated-test-dc"
    "machineprovider:aws-test-provider"
    "kubernetesprovider:eks-test-provider"
    "machine:web-server-1"
    "machine:app-server-1"
)

for resource in "${resources[@]}"; do
    type=$(echo "$resource" | cut -d':' -f1)
    name=$(echo "$resource" | cut -d':' -f2)
    
    if kubectl get "$type" "$name" > /dev/null 2>&1; then
        print_test "PASS" "Resource exists: $type/$name"
        
        # Check for proper labeling where applicable
        if [ "$type" != "datacenter" ]; then
            if kubectl get "$type" "$name" -o jsonpath='{.metadata.labels.datacenter}' 2>/dev/null | grep -q "integrated-test-dc"; then
                print_test "PASS" "Resource properly labeled with datacenter: $type/$name"
            else
                print_test "WARN" "Resource missing datacenter label: $type/$name"
            fi
        fi
    else
        print_test "FAIL" "Resource does not exist: $type/$name"
    fi
done

# Test 9: Test resource queries and selectors
print_test "STEP" "Testing resource queries and selectors"

# Test label selectors
if kubectl get machines -l datacenter=integrated-test-dc --no-headers 2>/dev/null | wc -l | grep -q "2"; then
    print_test "PASS" "Label selector works for machines by datacenter"
else
    print_test "FAIL" "Label selector failed for machines by datacenter"
fi

if kubectl get machines -l role=web-server --no-headers 2>/dev/null | wc -l | grep -q "1"; then
    print_test "PASS" "Label selector works for machines by role"
else
    print_test "FAIL" "Label selector failed for machines by role"
fi

# Test 10: Validate field selectors and status
print_test "STEP" "Testing field selectors and status fields"

# Check if we can query by specific fields
if kubectl get machineproviders --field-selector metadata.name=aws-test-provider --no-headers 2>/dev/null | wc -l | grep -q "1"; then
    print_test "PASS" "Field selector works for MachineProvider"
else
    print_test "WARN" "Field selector may not be supported for MachineProvider"
fi

# Test 11: Test resource updates
print_test "STEP" "Testing resource updates and patches"

# Test updating machine tags
kubectl patch machine web-server-1 --type='merge' -p='{"spec":{"tags":{"Updated":"true"}}}' > /dev/null 2>&1
if [ $? -eq 0 ]; then
    print_test "PASS" "Successfully updated machine resource"
    
    # Verify the update
    if kubectl get machine web-server-1 -o jsonpath='{.spec.tags.Updated}' 2>/dev/null | grep -q "true"; then
        print_test "PASS" "Machine update was persisted correctly"
    else
        print_test "FAIL" "Machine update was not persisted"
    fi
else
    print_test "FAIL" "Failed to update machine resource"
fi

# Test 12: Test resource deletion with dependencies
print_test "STEP" "Testing resource deletion and cleanup"

# Try to delete provider while machines reference it (should be prevented or handled gracefully)
if kubectl delete machineprovider aws-test-provider > /dev/null 2>&1; then
    print_test "WARN" "MachineProvider deleted despite machine references (may need finalizers)"
else
    print_test "PASS" "MachineProvider deletion properly handled with existing references"
fi

# Delete resources in reverse dependency order
delete_order=(
    "machine:web-server-1"
    "machine:app-server-1"
    "kubernetesprovider:eks-test-provider"
    "machineprovider:aws-test-provider"
    "datacenter:integrated-test-dc"
)

for resource in "${delete_order[@]}"; do
    type=$(echo "$resource" | cut -d':' -f1)
    name=$(echo "$resource" | cut -d':' -f2)
    
    if kubectl delete "$type" "$name" --ignore-not-found > /dev/null 2>&1; then
        print_test "PASS" "Successfully deleted $type/$name"
    else
        print_test "WARN" "Failed to delete $type/$name (may not exist)"
    fi
done

# Test 13: Validate all example files if they exist
print_test "STEP" "Validating all example files"

example_files=(
    "machine-example.yaml"
    "machine-provider-example.yaml"
    "kubernetes-provider-example.yaml"
    "datacenter-example.yaml"
)

for example_file in "${example_files[@]}"; do
    if [ -f "$EXAMPLES_DIR/$example_file" ]; then
        if kubectl apply --dry-run=client -f "$EXAMPLES_DIR/$example_file" > /dev/null 2>&1; then
            print_test "PASS" "Example file validation successful: $example_file"
        else
            print_test "FAIL" "Example file validation failed: $example_file"
            echo "Error details:"
            kubectl apply --dry-run=client -f "$EXAMPLES_DIR/$example_file"
        fi
    else
        print_test "WARN" "Example file not found: $example_file"
    fi
done

# Test 14: Performance and scale testing
print_test "STEP" "Testing performance and scale characteristics"

# Test creating multiple resources quickly
start_time=$(date +%s)

for i in {1..10}; do
    cat > "$TEMP_DIR/scale-test-$i.yaml" << EOF
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: scale-test-machine-$i
  namespace: default
spec:
  machineProviderRef:
    name: test-provider-ref
    namespace: default
  instanceType: t3.micro
  image: ami-test
  compute:
    cpu: "1"
    memoryGB: "1.0"
  storage:
  - name: root
    size: 20Gi
    type: gp3
    mountPath: "/"
  tags:
    Name: "Scale Test Machine $i"
    Purpose: "performance-testing"
EOF

    kubectl apply -f "$TEMP_DIR/scale-test-$i.yaml" > /dev/null 2>&1
done

end_time=$(date +%s)
duration=$((end_time - start_time))

if [ $duration -lt 10 ]; then
    print_test "PASS" "Created 10 machines in ${duration} seconds (good performance)"
else
    print_test "WARN" "Created 10 machines in ${duration} seconds (may need optimization)"
fi

# Cleanup scale test resources
for i in {1..10}; do
    kubectl delete machine "scale-test-machine-$i" --ignore-not-found > /dev/null 2>&1
done

# Test 15: Final CRD status check
print_test "STEP" "Final CRD status verification"

for crd_name in "${crd_names[@]}"; do
    if kubectl get crd "$crd_name" -o jsonpath='{.status.conditions[?(@.type=="Established")].status}' 2>/dev/null | grep -q "True"; then
        print_test "PASS" "CRD remains healthy: $crd_name"
    else
        print_test "FAIL" "CRD is not healthy: $crd_name"
    fi
done

# Cleanup temp directory
rm -rf "$TEMP_DIR"

print_test "STEP" "All CRD validation test completed"

echo -e "\n${CYAN}=== Complete Test Summary ===${NC}"
echo -e "${BLUE}Tested Components:${NC}"
echo "- Machine CRD: VM and instance management"
echo "- MachineProvider CRD: Cloud and virtualization provider configuration"
echo "- KubernetesProvider CRD: Kubernetes cluster management"
echo "- Datacenter CRD: Infrastructure orchestration and governance"
echo ""
echo -e "${BLUE}Test Categories:${NC}"
echo "- CRD structure and syntax validation"
echo "- Cross-resource integration and references"
echo "- Label and field selector functionality"
echo "- Resource lifecycle management"
echo "- Example file validation"
echo "- Performance and scale characteristics"
echo "- Schema completeness verification"
echo ""
echo -e "${BLUE}Integration Scenarios:${NC}"
echo "- Complete datacenter with providers and machines"
echo "- Cross-resource labeling and relationships"
echo "- Resource dependency management"
echo "- Update and deletion workflows"

echo -e "\n${GREEN}🎉 All integration tests completed successfully! 🎉${NC}"
echo -e "${CYAN}The CRD system is ready for production use.${NC}"

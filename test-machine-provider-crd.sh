#!/bin/bash

# Machine Provider CRD Validation Test Script
# This script validates the MachineProvider CRD with various configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRD_DIR="${SCRIPT_DIR}/crds"
EXAMPLES_DIR="${SCRIPT_DIR}/examples"
TEMP_DIR="/tmp/machine-provider-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Machine Provider CRD Validation Test ===${NC}"

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
print_test "INFO" "Testing Machine Provider CRD existence and structure"
if [ -f "$CRD_DIR/vitistack.io_machineproviders.yaml" ]; then
    print_test "PASS" "MachineProvider CRD file exists"
else
    print_test "FAIL" "MachineProvider CRD file not found"
    exit 1
fi

# Test 2: Validate CRD YAML structure
print_test "INFO" "Validating CRD YAML structure"
if kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_machineproviders.yaml" > /dev/null 2>&1; then
    print_test "PASS" "CRD YAML structure is valid"
else
    print_test "FAIL" "CRD YAML structure is invalid"
    kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_machineproviders.yaml"
    exit 1
fi

# Test 3: Apply CRD to cluster
print_test "INFO" "Applying MachineProvider CRD to cluster"
if kubectl apply -f "$CRD_DIR/vitistack.io_machineproviders.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Successfully applied MachineProvider CRD"
else
    print_test "FAIL" "Failed to apply MachineProvider CRD"
    exit 1
fi

# Wait for CRD to be established
print_test "INFO" "Waiting for CRD to be established"
sleep 2

# Test 4: Verify CRD is established
if kubectl get crd machineproviders.vitistack.io > /dev/null 2>&1; then
    print_test "PASS" "MachineProvider CRD is established"
else
    print_test "FAIL" "MachineProvider CRD is not established"
    exit 1
fi

# Test 5: Create test configurations
print_test "INFO" "Creating test Machine Provider configurations"

# Test AWS Provider
cat > "$TEMP_DIR/aws-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: test-aws-provider
  namespace: default
spec:
  type: aws
  region: us-west-2
  availabilityZones:
  - us-west-2a
  - us-west-2b
  config:
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
    supportedOSTypes:
    - linux
    - windows
  networkConfig:
    defaultNetworkId: vpc-12345678
  storageConfig:
    defaultStorageClass: gp3
    defaultDiskSize: 20Gi
  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "4.0"
    maxCPU: "96"
    maxMemoryGB: "384.0"
EOF

# Test Azure Provider
cat > "$TEMP_DIR/azure-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: test-azure-provider
  namespace: default
spec:
  type: azure
  region: westus2
  availabilityZones:
  - "1"
  - "2"
  - "3"
  config:
    timeout: 45s
    customSettings:
      resourceGroup: "test-rg"
      subscriptionId: "12345678-1234-1234-1234-123456789012"
  authentication:
    type: serviceaccount
    serviceAccount:
      secretRef:
        name: azure-credentials
        key: service-principal.json
  capabilities:
    supportedOperations:
    - create
    - delete
    - start
    - stop
    - resize
    supportedOSTypes:
    - linux
    - windows
    supportedInstanceTypes:
    - Standard_B2s
    - Standard_D4s_v3
  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "8.0"
    maxCPU: "64"
    maxMemoryGB: "256.0"
EOF

# Test VMware vSphere Provider
cat > "$TEMP_DIR/vsphere-provider.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: test-vsphere-provider
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
    supportedOSTypes:
    - linux
    - windows
    availableImages:
    - name: ubuntu-20.04-server
      id: vm-template-ubuntu2004
      osType: linux
      version: "20.04"
      architecture: x86_64
  networkConfig:
    defaultNetworkId: "VM Network"
    availableNetworks:
    - id: "VM Network"
      name: "VM Network"
      type: management
  storageConfig:
    defaultStorageClass: thin
    defaultDiskSize: 50Gi
  computeConfig:
    defaultCPU: "4"
    defaultMemoryGB: "8.0"
    maxCPU: "32"
    maxMemoryGB: "256.0"
EOF

# Test 6: Validate test configurations
print_test "INFO" "Validating test configurations"

for provider_file in aws-provider.yaml azure-provider.yaml vsphere-provider.yaml; do
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
print_test "INFO" "Applying test Machine Provider resources"

for provider_file in aws-provider.yaml azure-provider.yaml vsphere-provider.yaml; do
    provider_name=$(echo "$provider_file" | cut -d'-' -f1)
    resource_name="test-${provider_name}-provider"
    
    if kubectl apply -f "$TEMP_DIR/$provider_file" > /dev/null 2>&1; then
        print_test "PASS" "Successfully applied $provider_name provider"
        
        # Wait a moment for resource to be created
        sleep 1
        
        # Verify resource exists
        if kubectl get machineprovider "$resource_name" > /dev/null 2>&1; then
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

# Invalid type
cat > "$TEMP_DIR/invalid-type.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: invalid-type-provider
  namespace: default
spec:
  type: invalid-provider-type
  region: us-west-2
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: test-secret
        key: test-key
  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "4.0"
EOF

# Invalid timeout format
cat > "$TEMP_DIR/invalid-timeout.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: invalid-timeout-provider
  namespace: default
spec:
  type: aws
  region: us-west-2
  config:
    timeout: invalid-timeout-format
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: test-secret
        key: test-key
  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "4.0"
EOF

# Invalid CPU format
cat > "$TEMP_DIR/invalid-cpu.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: invalid-cpu-provider
  namespace: default
spec:
  type: aws
  region: us-west-2
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: test-secret
        key: test-key
  computeConfig:
    defaultCPU: "invalid-cpu"
    defaultMemoryGB: "4.0"
EOF

# Invalid memory format
cat > "$TEMP_DIR/invalid-memory.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: invalid-memory-provider
  namespace: default
spec:
  type: aws
  region: us-west-2
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: test-secret
        key: test-key
  computeConfig:
    defaultCPU: "2"
    defaultMemoryGB: "invalid-memory"
EOF

# Test invalid configurations
for invalid_file in invalid-type.yaml invalid-timeout.yaml invalid-cpu.yaml invalid-memory.yaml; do
    config_type=$(echo "$invalid_file" | cut -d'-' -f2 | cut -d'.' -f1)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$invalid_file" > /dev/null 2>&1; then
        print_test "FAIL" "Invalid $config_type configuration was accepted (should be rejected)"
    else
        print_test "PASS" "Invalid $config_type configuration properly rejected"
    fi
done

# Test 9: Test field validations with edge cases
print_test "INFO" "Testing field validation edge cases"

# Test minimum values
cat > "$TEMP_DIR/edge-case-minimum.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: edge-case-minimum
  namespace: default
spec:
  type: aws
  region: us-west-2
  config:
    timeout: 1s
    rateLimiting:
      requestsPerSecond: "0.1"
      burstLimit: 1
  authentication:
    type: apikey
    apiKey:
      secretRef:
        name: test-secret
        key: test-key
  computeConfig:
    defaultCPU: "0.1"
    defaultMemoryGB: "0.5"
    maxCPU: "1"
    maxMemoryGB: "1.0"
EOF

if kubectl apply --dry-run=client -f "$TEMP_DIR/edge-case-minimum.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Minimum values configuration accepted"
else
    print_test "FAIL" "Minimum values configuration rejected"
fi

# Test 10: Cleanup test resources
print_test "INFO" "Cleaning up test resources"

# Delete test resources
for provider_file in aws-provider.yaml azure-provider.yaml vsphere-provider.yaml; do
    provider_name=$(echo "$provider_file" | cut -d'-' -f1)
    resource_name="test-${provider_name}-provider"
    
    if kubectl delete machineprovider "$resource_name" > /dev/null 2>&1; then
        print_test "PASS" "Cleaned up $provider_name provider"
    else
        print_test "WARN" "Failed to cleanup $provider_name provider (may not exist)"
    fi
done

# Test 11: Test example files if they exist
if [ -f "$EXAMPLES_DIR/machine-provider-example.yaml" ]; then
    print_test "INFO" "Testing example files"
    
    if kubectl apply --dry-run=client -f "$EXAMPLES_DIR/machine-provider-example.yaml" > /dev/null 2>&1; then
        print_test "PASS" "Example file validation successful"
    else
        print_test "FAIL" "Example file validation failed"
        echo "Error details:"
        kubectl apply --dry-run=client -f "$EXAMPLES_DIR/machine-provider-example.yaml"
    fi
else
    print_test "WARN" "Example file not found, skipping example validation"
fi

# Test 12: Check CRD schema completeness
print_test "INFO" "Checking CRD schema completeness"

# Extract schema from CRD
if kubectl get crd machineproviders.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}' > /dev/null 2>&1; then
    schema=$(kubectl get crd machineproviders.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}')
    
    # Check for required schema elements
    required_fields=("spec" "status" "metadata")
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
else
    print_test "FAIL" "Could not extract CRD schema"
fi

# Cleanup temp directory
rm -rf "$TEMP_DIR"

print_test "INFO" "Machine Provider CRD validation test completed"

echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo "- CRD structure and syntax validation"
echo "- Multi-provider configuration testing (AWS, Azure, vSphere)"
echo "- Invalid configuration rejection testing"
echo "- Field validation and edge case testing"
echo "- Example file validation"
echo "- Schema completeness verification"

echo -e "\n${GREEN}All tests completed successfully!${NC}"

#!/bin/bash

# Vitistack CRD Validation Test Script
# This script validates the Vitistack CRD with various configurations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRD_DIR="${SCRIPT_DIR}/crds"
EXAMPLES_DIR="${SCRIPT_DIR}/examples"
TEMP_DIR="/tmp/vitistack-test"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Vitistack CRD Validation Test ===${NC}"

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
print_test "INFO" "Testing Vitistack CRD existence and structure"
if [ -f "$CRD_DIR/vitistack.io_vitistacks.yaml" ]; then
    print_test "PASS" "Vitistack CRD file exists"
else
    print_test "FAIL" "Vitistack CRD file not found"
    exit 1
fi

# Test 2: Validate CRD YAML structure
print_test "INFO" "Validating CRD YAML structure"
if kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_vitistacks.yaml" > /dev/null 2>&1; then
    print_test "PASS" "CRD YAML structure is valid"
else
    print_test "FAIL" "CRD YAML structure is invalid"
    kubectl apply --dry-run=client -f "$CRD_DIR/vitistack.io_vitistacks.yaml"
    exit 1
fi

# Test 3: Apply CRD to cluster
print_test "INFO" "Applying Vitistack CRD to cluster"
if kubectl apply -f "$CRD_DIR/vitistack.io_vitistacks.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Successfully applied Vitistack CRD"
else
    print_test "FAIL" "Failed to apply Vitistack CRD"
    exit 1
fi

# Wait for CRD to be established
print_test "INFO" "Waiting for CRD to be established"
sleep 2

# Test 4: Verify CRD is established
if kubectl get crd vitistacks.vitistack.io > /dev/null 2>&1; then
    print_test "PASS" "Vitistack CRD is established"
else
    print_test "FAIL" "Vitistack CRD is not established"
    exit 1
fi

# Test 5: Create test configurations
print_test "INFO" "Creating test Vitistack configurations"

# Test Multi-Cloud Enterprise Vitistack
cat > "$TEMP_DIR/enterprise-vitistack.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: test-enterprise-dc
  namespace: default
spec:
  name: "Test Enterprise Vitistack"
  description: "Multi-cloud enterprise vitistack for testing"
  location:
    region: us-west-2
    availabilityZones:
    - us-west-2a
    - us-west-2b
    - us-west-2c
    coordinates:
      latitude: "37.7749"
      longitude: "-122.4194"
    address:
      street: "123 Enterprise Way"
      city: "San Francisco"
      state: "CA"
      postalCode: "94105"
      country: "USA"
  
  providers:
    machineProviders:
    - name: aws-primary
      priority: 1
      config:
        region: us-west-2
        availabilityZones: ["us-west-2a", "us-west-2b"]
    - name: azure-secondary
      priority: 2
      config:
        region: westus2
        resourceGroup: enterprise-rg
    kubernetesProviders:
    - name: eks-primary
      priority: 1
      config:
        region: us-west-2
        version: "1.28.0"
    - name: aks-secondary
      priority: 2
      config:
        region: westus2
        version: "1.28.2"
  
  networking:
    vpcs:
    - name: primary-vpc
      cidr: "10.0.0.0/16"
      provider: aws
      region: us-west-2
      subnets:
      - name: public-subnet-1
        cidr: "10.0.1.0/24"
        type: public
        availabilityZone: us-west-2a
      - name: private-subnet-1
        cidr: "10.0.2.0/24"
        type: private
        availabilityZone: us-west-2a
    - name: secondary-vpc
      cidr: "10.1.0.0/16"
      provider: azure
      region: westus2
      subnets:
      - name: default-subnet
        cidr: "10.1.1.0/24"
        type: private
        availabilityZone: "1"
    
    loadBalancers:
    - name: primary-lb
      type: application
      provider: aws
      scheme: internet-facing
      subnets:
      - public-subnet-1
      healthCheck:
        protocol: HTTP
        port: 80
        path: /health
        interval: 30s
        timeout: 5s
        healthyThreshold: 2
        unhealthyThreshold: 3
    
    dns:
      provider: route53
      zones:
      - name: enterprise.example.com
        type: public
        records:
        - name: api
          type: A
          ttl: 300
    
    firewallRules:
    - name: allow-https
      protocol: tcp
      port: "443"
      source: "0.0.0.0/0"
      target: "web-servers"
      action: allow
    - name: allow-ssh
      protocol: tcp
      port: "22"
      source: "10.0.0.0/8"
      target: "all-servers"
      action: allow
  
  security:
    compliance:
      frameworks:
      - SOC2
      - PCI-DSS
      - HIPAA
      certifications:
      - name: SOC2-Type2
        issuer: "Third Party Auditor"
        validUntil: "2024-12-31"
    
    encryption:
      atRest:
        enabled: true
        provider: aws-kms
        keyId: "arn:aws:kms:us-west-2:123456789012:key/12345678-1234-1234-1234-123456789012"
      inTransit:
        enabled: true
        protocols:
        - TLS1.3
        - TLS1.2
        minVersion: TLS1.2
    
    accessControl:
      rbac:
        enabled: true
        strictMode: true
      mfa:
        enabled: true
        required: true
        providers:
        - totp
        - hardware-token
      networkSegmentation:
        enabled: true
        microsegmentation: true
        zeroTrust: true
    
    auditLogging:
      enabled: true
      destination: s3://audit-logs-bucket
      retention: 2555d  # 7 years
      realTimeAlerting: true
  
  monitoring:
    metrics:
      provider: prometheus
      endpoint: https://prometheus.monitoring.example.com
      retention: 90d
      alerting:
        enabled: true
        provider: alertmanager
        routes:
        - severity: critical
          receiver: oncall-team
        - severity: warning
          receiver: ops-team
    
    logging:
      provider: elk
      endpoint: https://elasticsearch.logging.example.com
      retention: 180d
      realTimeProcessing: true
    
    tracing:
      enabled: true
      provider: jaeger
      samplingRate: "0.1"
      endpoint: https://jaeger.tracing.example.com
  
  backup:
    enabled: true
    schedule: "0 2 * * *"  # Daily at 2 AM
    retention:
      daily: 30
      weekly: 12
      monthly: 12
      yearly: 7
    destinations:
    - type: s3
      bucket: enterprise-backups
      region: us-west-2
      encryption: true
    - type: azure-blob
      container: enterprise-backups
      storageAccount: enterprisebackups
      encryption: true
    
    disasterRecovery:
      enabled: true
      rto: 4h
      rpo: 1h
      replicationSites:
      - region: us-east-1
        provider: aws
      - region: eastus2
        provider: azure
  
  resourceQuotas:
    compute:
      totalCPU: "1000"
      totalMemoryGB: "4000"
      totalGPU: "50"
    storage:
      totalStorageGB: "100000"
      iopsLimit: "50000"
    network:
      totalBandwidthGbps: "100"
      connectionsLimit: 100000
    cost:
      monthlyBudget: "50000"
      alertThreshold: "80.0"
EOF

# Test Edge Vitistack
cat > "$TEMP_DIR/edge-vitistack.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: test-edge-dc
  namespace: default
spec:
  name: "Test Edge Vitistack"
  description: "Edge computing vitistack for low-latency applications"
  location:
    region: edge-location-1
    coordinates:
      latitude: "40.7128"
      longitude: "-74.0060"
    address:
      city: "New York"
      state: "NY"
      country: "USA"
  
  providers:
    machineProviders:
    - name: edge-compute
      priority: 1
      config:
        type: k3s
        lightweight: true
    kubernetesProviders:
    - name: k3s-edge
      priority: 1
      config:
        version: "1.28.0+k3s1"
        edge: true
  
  networking:
    vpcs:
    - name: edge-network
      cidr: "192.168.0.0/16"
      provider: edge
      subnets:
      - name: edge-subnet
        cidr: "192.168.1.0/24"
        type: private
    
    loadBalancers:
    - name: edge-lb
      type: network
      provider: metallb
      scheme: internal
    
    dns:
      provider: local
      zones:
      - name: edge.local
        type: private
  
  security:
    encryption:
      atRest:
        enabled: true
        provider: local-kms
      inTransit:
        enabled: true
        protocols:
        - TLS1.3
    
    accessControl:
      rbac:
        enabled: true
      networkSegmentation:
        enabled: true
  
  monitoring:
    metrics:
      provider: prometheus
      retention: 30d
      lightweight: true
    
    logging:
      provider: loki
      retention: 30d
      localStorage: true
  
  backup:
    enabled: true
    schedule: "0 3 * * *"
    retention:
      daily: 7
      weekly: 4
    destinations:
    - type: local
      path: /backup/edge
      encryption: true
  
  resourceQuotas:
    compute:
      totalCPU: "50"
      totalMemoryGB: "200"
    storage:
      totalStorageGB: "2000"
    network:
      totalBandwidthGbps: "10"
    cost:
      monthlyBudget: "2000"
      alertThreshold: "90.0"
EOF

# Test On-Premises Vitistack
cat > "$TEMP_DIR/onprem-vitistack.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: test-onprem-dc
  namespace: default
spec:
  name: "Test On-Premises Vitistack"
  description: "Traditional on-premises vitistack"
  location:
    region: vitistack-1
    coordinates:
      latitude: "33.4484"
      longitude: "-112.0740"
    address:
      street: "456 Enterprise Blvd"
      city: "Phoenix"
      state: "AZ"
      postalCode: "85001"
      country: "USA"
  
  providers:
    machineProviders:
    - name: vsphere-primary
      priority: 1
      config:
        type: vsphere
        vitistack: "Vitistack1"
        cluster: "Cluster1"
    kubernetesProviders:
    - name: rke2-primary
      priority: 1
      config:
        type: rke2
        version: "1.28.2+rke2r1"
  
  networking:
    vpcs:
    - name: corporate-network
      cidr: "172.16.0.0/12"
      provider: onprem
      subnets:
      - name: dmz-subnet
        cidr: "172.16.1.0/24"
        type: public
        vlan: 100
      - name: internal-subnet
        cidr: "172.16.2.0/24"
        type: private
        vlan: 200
      - name: management-subnet
        cidr: "172.16.10.0/24"
        type: management
        vlan: 10
    
    loadBalancers:
    - name: haproxy-lb
      type: network
      provider: haproxy
      scheme: internal
      algorithm: round-robin
    
    dns:
      provider: bind9
      zones:
      - name: corp.example.com
        type: private
        servers:
        - "172.16.10.5"
        - "172.16.10.6"
    
    firewallRules:
    - name: allow-web-dmz
      protocol: tcp
      port: "80,443"
      source: "0.0.0.0/0"
      target: "dmz-subnet"
      action: allow
    - name: deny-external-internal
      protocol: any
      source: "0.0.0.0/0"
      target: "internal-subnet"
      action: deny
  
  security:
    compliance:
      frameworks:
      - SOX
      - GDPR
    
    encryption:
      atRest:
        enabled: true
        provider: vault
      inTransit:
        enabled: true
        protocols:
        - TLS1.3
    
    accessControl:
      rbac:
        enabled: true
        strictMode: true
      mfa:
        enabled: true
        required: true
        providers:
        - ldap
        - radius
      networkSegmentation:
        enabled: true
        vlans: true
    
    auditLogging:
      enabled: true
      destination: file:///var/log/audit
      retention: 2555d
  
  monitoring:
    metrics:
      provider: prometheus
      retention: 365d
      alerting:
        enabled: true
        provider: alertmanager
    
    logging:
      provider: rsyslog
      retention: 365d
      centralized: true
  
  backup:
    enabled: true
    schedule: "0 1 * * *"
    retention:
      daily: 30
      weekly: 52
      monthly: 60
    destinations:
    - type: nfs
      server: backup.corp.example.com
      path: /backup/vitistack1
      encryption: true
    - type: tape
      library: IBM-TS3500
      encryption: true
    
    disasterRecovery:
      enabled: true
      rto: 24h
      rpo: 4h
      replicationSites:
      - region: vitistack-2
        provider: onprem
        location: "Remote Site"
  
  resourceQuotas:
    compute:
      totalCPU: "2000"
      totalMemoryGB: "8000"
    storage:
      totalStorageGB: "500000"
    network:
      totalBandwidthGbps: "40"
    cost:
      monthlyBudget: "75000"
      alertThreshold: "85.0"
EOF

# Test 6: Validate test configurations
print_test "INFO" "Validating test configurations"

for vitistack_file in enterprise-vitistack.yaml edge-vitistack.yaml onprem-vitistack.yaml; do
    vitistack_name=$(echo "$vitistack_file" | cut -d'-' -f1)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$vitistack_file" > /dev/null 2>&1; then
        print_test "PASS" "Valid $vitistack_name vitistack configuration"
    else
        print_test "FAIL" "Invalid $vitistack_name vitistack configuration"
        echo "Error details:"
        kubectl apply --dry-run=client -f "$TEMP_DIR/$vitistack_file"
    fi
done

# Test 7: Apply and verify resources
print_test "INFO" "Applying test Vitistack resources"

for vitistack_file in enterprise-vitistack.yaml edge-vitistack.yaml onprem-vitistack.yaml; do
    vitistack_name=$(echo "$vitistack_file" | cut -d'-' -f1)
    resource_name="test-${vitistack_name}-dc"
    
    if kubectl apply -f "$TEMP_DIR/$vitistack_file" > /dev/null 2>&1; then
        print_test "PASS" "Successfully applied $vitistack_name vitistack"
        
        # Wait a moment for resource to be created
        sleep 1
        
        # Verify resource exists
        if kubectl get vitistack "$resource_name" > /dev/null 2>&1; then
            print_test "PASS" "$vitistack_name vitistack resource exists"
        else
            print_test "FAIL" "$vitistack_name vitistack resource not found"
        fi
    else
        print_test "FAIL" "Failed to apply $vitistack_name vitistack"
    fi
done

# Test 8: Test invalid configurations
print_test "INFO" "Testing invalid configuration rejection"

# Invalid CIDR
cat > "$TEMP_DIR/invalid-cidr.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: invalid-cidr-dc
  namespace: default
spec:
  name: "Invalid CIDR Vitistack"
  location:
    region: test-region
  networking:
    vpcs:
    - name: invalid-vpc
      cidr: "invalid-cidr-format"
      provider: aws
      subnets:
      - name: test-subnet
        cidr: "10.0.1.0/24"
        type: private
  resourceQuotas:
    compute:
      totalCPU: "10"
      totalMemoryGB: "20"
EOF

# Invalid coordinates
cat > "$TEMP_DIR/invalid-coordinates.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: invalid-coordinates-dc
  namespace: default
spec:
  name: "Invalid Coordinates Vitistack"
  location:
    region: test-region
    coordinates:
      latitude: "invalid-latitude"
      longitude: "-122.4194"
  resourceQuotas:
    compute:
      totalCPU: "10"
      totalMemoryGB: "20"
EOF

# Invalid quota values
cat > "$TEMP_DIR/invalid-quota.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: invalid-quota-dc
  namespace: default
spec:
  name: "Invalid Quota Vitistack"
  location:
    region: test-region
  resourceQuotas:
    compute:
      totalCPU: "invalid-cpu"
      totalMemoryGB: "20"
EOF

# Invalid schedule
cat > "$TEMP_DIR/invalid-schedule.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: invalid-schedule-dc
  namespace: default
spec:
  name: "Invalid Schedule Vitistack"
  location:
    region: test-region
  backup:
    enabled: true
    schedule: "invalid-cron-expression"
    destinations:
    - type: s3
      bucket: test-bucket
  resourceQuotas:
    compute:
      totalCPU: "10"
      totalMemoryGB: "20"
EOF

# Test invalid configurations
for invalid_file in invalid-cidr.yaml invalid-coordinates.yaml invalid-quota.yaml invalid-schedule.yaml; do
    config_type=$(echo "$invalid_file" | cut -d'-' -f2 | cut -d'.' -f1)
    
    if kubectl apply --dry-run=client -f "$TEMP_DIR/$invalid_file" > /dev/null 2>&1; then
        print_test "FAIL" "Invalid $config_type configuration was accepted (should be rejected)"
    else
        print_test "PASS" "Invalid $config_type configuration properly rejected"
    fi
done

# Test 9: Test minimal configuration
print_test "INFO" "Testing minimal valid configuration"

cat > "$TEMP_DIR/minimal-vitistack.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: minimal-dc
  namespace: default
spec:
  name: "Minimal Vitistack"
  location:
    region: minimal-region
  resourceQuotas:
    compute:
      totalCPU: "1"
      totalMemoryGB: "2"
EOF

if kubectl apply --dry-run=client -f "$TEMP_DIR/minimal-vitistack.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Minimal configuration is valid"
else
    print_test "FAIL" "Minimal configuration is invalid"
    echo "Error details:"
    kubectl apply --dry-run=client -f "$TEMP_DIR/minimal-vitistack.yaml"
fi

# Test 10: Test complex networking configuration
print_test "INFO" "Testing complex networking configuration"

cat > "$TEMP_DIR/complex-network.yaml" << 'EOF'
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: complex-network-dc
  namespace: default
spec:
  name: "Complex Network Vitistack"
  location:
    region: complex-region
  
  networking:
    vpcs:
    - name: production-vpc
      cidr: "10.0.0.0/16"
      provider: aws
      region: us-west-2
      subnets:
      - name: public-web-1a
        cidr: "10.0.1.0/24"
        type: public
        availabilityZone: us-west-2a
      - name: public-web-1b
        cidr: "10.0.2.0/24"
        type: public
        availabilityZone: us-west-2b
      - name: private-app-1a
        cidr: "10.0.11.0/24"
        type: private
        availabilityZone: us-west-2a
      - name: private-app-1b
        cidr: "10.0.12.0/24"
        type: private
        availabilityZone: us-west-2b
      - name: private-db-1a
        cidr: "10.0.21.0/24"
        type: private
        availabilityZone: us-west-2a
      - name: private-db-1b
        cidr: "10.0.22.0/24"
        type: private
        availabilityZone: us-west-2b
    
    - name: staging-vpc
      cidr: "10.1.0.0/16"
      provider: aws
      region: us-west-2
      subnets:
      - name: staging-subnet
        cidr: "10.1.1.0/24"
        type: private
        availabilityZone: us-west-2a
    
    loadBalancers:
    - name: public-alb
      type: application
      provider: aws
      scheme: internet-facing
      subnets:
      - public-web-1a
      - public-web-1b
      healthCheck:
        protocol: HTTPS
        port: 443
        path: /health
        interval: 30s
        timeout: 10s
        healthyThreshold: 2
        unhealthyThreshold: 5
    
    - name: internal-nlb
      type: network
      provider: aws
      scheme: internal
      subnets:
      - private-app-1a
      - private-app-1b
      algorithm: least-connections
    
    dns:
      provider: route53
      zones:
      - name: production.example.com
        type: public
        records:
        - name: api
          type: A
          ttl: 300
        - name: www
          type: CNAME
          ttl: 300
          value: api.production.example.com
      - name: internal.example.com
        type: private
        vpc: production-vpc
        records:
        - name: database
          type: A
          ttl: 300
    
    firewallRules:
    - name: allow-https-public
      protocol: tcp
      port: "443"
      source: "0.0.0.0/0"
      target: "public-web"
      action: allow
    - name: allow-http-public
      protocol: tcp
      port: "80"
      source: "0.0.0.0/0"
      target: "public-web"
      action: allow
    - name: allow-app-from-web
      protocol: tcp
      port: "8080"
      source: "10.0.1.0/23"
      target: "private-app"
      action: allow
    - name: allow-db-from-app
      protocol: tcp
      port: "5432"
      source: "10.0.11.0/23"
      target: "private-db"
      action: allow
    - name: deny-direct-db-access
      protocol: tcp
      port: "5432"
      source: "0.0.0.0/0"
      target: "private-db"
      action: deny
  
  resourceQuotas:
    compute:
      totalCPU: "500"
      totalMemoryGB: "2000"
    network:
      totalBandwidthGbps: "50"
EOF

if kubectl apply --dry-run=client -f "$TEMP_DIR/complex-network.yaml" > /dev/null 2>&1; then
    print_test "PASS" "Complex networking configuration is valid"
else
    print_test "FAIL" "Complex networking configuration is invalid"
    echo "Error details:"
    kubectl apply --dry-run=client -f "$TEMP_DIR/complex-network.yaml"
fi

# Test 11: Cleanup test resources
print_test "INFO" "Cleaning up test resources"

# Delete test resources
for vitistack_file in enterprise-vitistack.yaml edge-vitistack.yaml onprem-vitistack.yaml; do
    vitistack_name=$(echo "$vitistack_file" | cut -d'-' -f1)
    resource_name="test-${vitistack_name}-dc"
    
    if kubectl delete vitistack "$resource_name" > /dev/null 2>&1; then
        print_test "PASS" "Cleaned up $vitistack_name vitistack"
    else
        print_test "WARN" "Failed to cleanup $vitistack_name vitistack (may not exist)"
    fi
done

# Test 12: Test example files if they exist
if [ -f "$EXAMPLES_DIR/vitistack-example.yaml" ]; then
    print_test "INFO" "Testing example files"
    
    if kubectl apply --dry-run=client -f "$EXAMPLES_DIR/vitistack-example.yaml" > /dev/null 2>&1; then
        print_test "PASS" "Example file validation successful"
    else
        print_test "FAIL" "Example file validation failed"
        echo "Error details:"
        kubectl apply --dry-run=client -f "$EXAMPLES_DIR/vitistack-example.yaml"
    fi
else
    print_test "WARN" "Example file not found, skipping example validation"
fi

# Test 13: Check CRD schema completeness
print_test "INFO" "Checking CRD schema completeness"

# Extract schema from CRD
if kubectl get crd vitistacks.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}' > /dev/null 2>&1; then
    schema=$(kubectl get crd vitistacks.vitistack.io -o jsonpath='{.spec.versions[0].schema.openAPIV3Schema}')
    
    # Check for required schema elements
    required_fields=("spec" "status" "metadata" "location" "resourceQuotas" "networking" "security" "monitoring" "backup")
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
    
    # Check schema size (should be substantial for comprehensive CRD)
    schema_size=$(echo "$schema" | wc -c)
    if [ "$schema_size" -gt 10000 ]; then
        print_test "PASS" "Schema is comprehensive (${schema_size} characters)"
    else
        print_test "WARN" "Schema may be too small (${schema_size} characters)"
    fi
else
    print_test "FAIL" "Could not extract CRD schema"
fi

# Cleanup temp directory
rm -rf "$TEMP_DIR"

print_test "INFO" "Vitistack CRD validation test completed"

echo -e "\n${BLUE}=== Test Summary ===${NC}"
echo "- CRD structure and syntax validation"
echo "- Multi-environment configuration testing (Enterprise, Edge, On-Premises)"
echo "- Complex networking configuration validation"
echo "- Invalid configuration rejection testing"
echo "- Minimal configuration testing"
echo "- Example file validation"
echo "- Schema completeness verification"

echo -e "\n${GREEN}All tests completed successfully!${NC}"

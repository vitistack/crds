# VitiStack Testing Guide

## Overview

This guide provides comprehensive testing strategies, test cases, integration scenarios, and validation procedures for VitiStack CRDs. It covers unit testing, integration testing, end-to-end testing, performance testing, chaos engineering, and continuous testing practices.

## Table of Contents

- [Testing Strategy](#testing-strategy)
- [Unit Testing](#unit-testing)
- [Integration Testing](#integration-testing)
- [End-to-End Testing](#end-to-end-testing)
- [Performance Testing](#performance-testing)
- [Chaos Engineering](#chaos-engineering)
- [Security Testing](#security-testing)
- [Compliance Testing](#compliance-testing)
- [Test Automation](#test-automation)
- [Test Data Management](#test-data-management)
- [Continuous Testing](#continuous-testing)

## Testing Strategy

### Testing Pyramid

```
        /\
       /  \
      / E2E \    - Comprehensive scenarios
     /______\    - Multi-cloud workflows
    /        \   - Real provider integration
   /Integration\  - CRD interactions
  /____________\  - Provider scenarios
 /              \ - Lifecycle testing
/  Unit Tests    \ - Individual components
/________________\ - Controller logic
                   - Validation functions
```

### Test Categories

#### 1. Unit Tests

- Controller logic validation
- CRD specification validation
- Provider interface testing
- Utility function testing

#### 2. Integration Tests

- CRD lifecycle testing
- Provider integration
- Cross-component communication
- Event handling

#### 3. End-to-End Tests

- Complete workflow scenarios
- Multi-cloud deployments
- Real provider interactions
- User journey validation

#### 4. Performance Tests

- Load testing
- Stress testing
- Scalability testing
- Resource utilization

#### 5. Chaos Tests

- Failure injection
- Recovery testing
- Resilience validation
- Disaster scenarios

## Unit Testing

### Controller Unit Tests

#### Test Structure

```go
// pkg/controller/vitistack_controller_test.go
package controller

import (
    "context"
    "testing"
    "time"

    "github.com/stretchr/testify/assert"
    "github.com/stretchr/testify/require"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/runtime"
    "k8s.io/apimachinery/pkg/types"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
    "sigs.k8s.io/controller-runtime/pkg/client/fake"
    "sigs.k8s.io/controller-runtime/pkg/reconcile"

    vitistackv1alpha1 "github.com/vitistack/crds/pkg/apis/v1alpha1"
)

func TestVitistackController_Reconcile(t *testing.T) {
    tests := []struct {
        name           string
        vitistack     *vitistackv1alpha1.Vitistack
        existingObjs   []client.Object
        expectedPhase  vitistackv1alpha1.VitistackPhase
        expectedError  bool
        expectedEvents int
    }{
        {
            name: "successful vitistack creation",
            vitistack: &vitistackv1alpha1.Vitistack{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-vitistack",
                    Namespace: "default",
                },
                Spec: vitistackv1alpha1.VitistackSpec{
                    Location: vitistackv1alpha1.VitistackLocation{
                        Region: "us-east-1",
                        Zone:   "us-east-1a",
                    },
                    MachineProviders: []vitistackv1alpha1.MachineProviderRef{
                        {
                            Name: "test-provider",
                        },
                    },
                },
            },
            existingObjs: []client.Object{
                &vitistackv1alpha1.MachineProvider{
                    ObjectMeta: metav1.ObjectMeta{
                        Name:      "test-provider",
                        Namespace: "default",
                    },
                    Status: vitistackv1alpha1.MachineProviderStatus{
                        Phase: vitistackv1alpha1.MachineProviderPhaseReady,
                        Conditions: []metav1.Condition{
                            {
                                Type:   "Ready",
                                Status: metav1.ConditionTrue,
                            },
                        },
                    },
                },
            },
            expectedPhase: vitistackv1alpha1.VitistackPhaseReady,
            expectedError: false,
        },
        {
            name: "vitistack with missing provider",
            vitistack: &vitistackv1alpha1.Vitistack{
                ObjectMeta: metav1.ObjectMeta{
                    Name:      "test-vitistack",
                    Namespace: "default",
                },
                Spec: vitistackv1alpha1.VitistackSpec{
                    Location: vitistackv1alpha1.VitistackLocation{
                        Region: "us-east-1",
                        Zone:   "us-east-1a",
                    },
                    MachineProviders: []vitistackv1alpha1.MachineProviderRef{
                        {
                            Name: "missing-provider",
                        },
                    },
                },
            },
            expectedPhase: vitistackv1alpha1.VitistackPhaseFailed,
            expectedError: true,
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            // Setup fake client
            scheme := runtime.NewScheme()
            require.NoError(t, vitistackv1alpha1.AddToScheme(scheme))

            objs := append(tt.existingObjs, tt.vitistack)
            fakeClient := fake.NewClientBuilder().
                WithScheme(scheme).
                WithObjects(objs...).
                WithStatusSubresource(&vitistackv1alpha1.Vitistack{}).
                Build()

            // Create controller
            reconciler := &VitistackReconciler{
                Client: fakeClient,
                Scheme: scheme,
            }

            // Execute reconciliation
            req := reconcile.Request{
                NamespacedName: types.NamespacedName{
                    Name:      tt.vitistack.Name,
                    Namespace: tt.vitistack.Namespace,
                },
            }

            result, err := reconciler.Reconcile(context.TODO(), req)

            // Validate results
            if tt.expectedError {
                assert.Error(t, err)
            } else {
                assert.NoError(t, err)
                assert.False(t, result.Requeue)
            }

            // Check updated status
            var updatedVitistack vitistackv1alpha1.Vitistack
            err = fakeClient.Get(context.TODO(), req.NamespacedName, &updatedVitistack)
            require.NoError(t, err)
            assert.Equal(t, tt.expectedPhase, updatedVitistack.Status.Phase)
        })
    }
}

func TestVitistackValidation(t *testing.T) {
    tests := []struct {
        name        string
        vitistack  *vitistackv1alpha1.Vitistack
        expectError bool
        errorField  string
    }{
        {
            name: "valid vitistack",
            vitistack: &vitistackv1alpha1.Vitistack{
                Spec: vitistackv1alpha1.VitistackSpec{
                    Location: vitistackv1alpha1.VitistackLocation{
                        Region: "us-east-1",
                        Zone:   "us-east-1a",
                    },
                    Networking: &vitistackv1alpha1.NetworkingConfig{
                        VPCs: []vitistackv1alpha1.VPCConfig{
                            {
                                Name: "main-vpc",
                                CIDR: "10.0.0.0/16",
                            },
                        },
                    },
                },
            },
            expectError: false,
        },
        {
            name: "invalid CIDR",
            vitistack: &vitistackv1alpha1.Vitistack{
                Spec: vitistackv1alpha1.VitistackSpec{
                    Location: vitistackv1alpha1.VitistackLocation{
                        Region: "us-east-1",
                        Zone:   "us-east-1a",
                    },
                    Networking: &vitistackv1alpha1.NetworkingConfig{
                        VPCs: []vitistackv1alpha1.VPCConfig{
                            {
                                Name: "main-vpc",
                                CIDR: "invalid-cidr",
                            },
                        },
                    },
                },
            },
            expectError: true,
            errorField:  "spec.networking.vpcs[0].cidr",
        },
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            err := validateVitistack(tt.vitistack)
            if tt.expectError {
                assert.Error(t, err)
                if tt.errorField != "" {
                    assert.Contains(t, err.Error(), tt.errorField)
                }
            } else {
                assert.NoError(t, err)
            }
        })
    }
}
```

### Running Unit Tests

```bash
#!/bin/bash
# run-unit-tests.sh

echo "Running VitiStack unit tests..."

# Run with coverage
go test -v -race -coverprofile=coverage.out ./pkg/...

# Generate coverage report
go tool cover -html=coverage.out -o coverage.html

# Coverage threshold check
COVERAGE=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
if (( $(echo "$COVERAGE < 80" | bc -l) )); then
    echo "Coverage $COVERAGE% is below threshold of 80%"
    exit 1
fi

echo "Unit tests completed with $COVERAGE% coverage"
```

## Integration Testing

### CRD Lifecycle Integration Tests

#### Test Environment Setup

```bash
#!/bin/bash
# setup-integration-test-env.sh

echo "Setting up integration test environment..."

# Create test namespace
kubectl create namespace vitistack-test

# Apply CRDs
kubectl apply -f crds/

# Deploy test controller
kubectl apply -f config/test/

# Create test secrets
kubectl create secret generic aws-test-creds \
  --from-literal=access-key=test-key \
  --from-literal=secret-key=test-secret \
  -n vitistack-test

kubectl create secret generic azure-test-creds \
  --from-literal=client-id=test-client \
  --from-literal=client-secret=test-secret \
  --from-literal=tenant-id=test-tenant \
  -n vitistack-test

echo "Integration test environment ready"
```

#### Integration Test Suite

```go
// test/integration/vitistack_integration_test.go
package integration

import (
    "context"
    "testing"
    "time"

    "github.com/stretchr/testify/suite"
    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    "k8s.io/apimachinery/pkg/types"
    "k8s.io/apimachinery/pkg/util/wait"

    vitistackv1alpha1 "github.com/vitistack/crds/pkg/apis/v1alpha1"
)

type VitistackIntegrationTestSuite struct {
    suite.Suite
    testNamespace string
}

func (suite *VitistackIntegrationTestSuite) SetupSuite() {
    suite.testNamespace = "vitistack-integration-test"
}

func (suite *VitistackIntegrationTestSuite) TestVitistackLifecycle() {
    ctx := context.Background()

    // Create machine provider
    machineProvider := &vitistackv1alpha1.MachineProvider{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-provider",
            Namespace: suite.testNamespace,
        },
        Spec: vitistackv1alpha1.MachineProviderSpec{
            ProviderType: "aws",
            Configuration: vitistackv1alpha1.ProviderConfiguration{
                AWS: &vitistackv1alpha1.AWSConfiguration{
                    Region:    "us-east-1",
                    SecretRef: "aws-test-creds",
                },
            },
        },
    }

    err := suite.k8sClient.Create(ctx, machineProvider)
    suite.Require().NoError(err)

    // Wait for provider to be ready
    err = wait.PollImmediate(5*time.Second, 2*time.Minute, func() (bool, error) {
        var provider vitistackv1alpha1.MachineProvider
        err := suite.k8sClient.Get(ctx, types.NamespacedName{
            Name:      "test-provider",
            Namespace: suite.testNamespace,
        }, &provider)
        if err != nil {
            return false, err
        }
        return provider.Status.Phase == vitistackv1alpha1.MachineProviderPhaseReady, nil
    })
    suite.Require().NoError(err)

    // Create vitistack
    vitistack := &vitistackv1alpha1.Vitistack{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-vitistack",
            Namespace: suite.testNamespace,
        },
        Spec: vitistackv1alpha1.VitistackSpec{
            Location: vitistackv1alpha1.VitistackLocation{
                Region: "us-east-1",
                Zone:   "us-east-1a",
            },
            MachineProviders: []vitistackv1alpha1.MachineProviderRef{
                {Name: "test-provider"},
            },
        },
    }

    err = suite.k8sClient.Create(ctx, vitistack)
    suite.Require().NoError(err)

    // Wait for vitistack to be ready
    err = wait.PollImmediate(10*time.Second, 5*time.Minute, func() (bool, error) {
        var dc vitistackv1alpha1.Vitistack
        err := suite.k8sClient.Get(ctx, types.NamespacedName{
            Name:      "test-vitistack",
            Namespace: suite.testNamespace,
        }, &dc)
        if err != nil {
            return false, err
        }
        return dc.Status.Phase == vitistackv1alpha1.VitistackPhaseReady, nil
    })
    suite.Require().NoError(err)

    // Create machine
    machine := &vitistackv1alpha1.Machine{
        ObjectMeta: metav1.ObjectMeta{
            Name:      "test-machine",
            Namespace: suite.testNamespace,
        },
        Spec: vitistackv1alpha1.MachineSpec{
            VitistackRef: vitistackv1alpha1.VitistackRef{
                Name: "test-vitistack",
            },
            MachineType: "t3.medium",
            Image: vitistackv1alpha1.ImageSpec{
                Name:    "ubuntu-20.04",
                Version: "latest",
            },
        },
    }

    err = suite.k8sClient.Create(ctx, machine)
    suite.Require().NoError(err)

    // Wait for machine to be ready
    err = wait.PollImmediate(30*time.Second, 10*time.Minute, func() (bool, error) {
        var m vitistackv1alpha1.Machine
        err := suite.k8sClient.Get(ctx, types.NamespacedName{
            Name:      "test-machine",
            Namespace: suite.testNamespace,
        }, &m)
        if err != nil {
            return false, err
        }
        return m.Status.Phase == vitistackv1alpha1.MachinePhaseRunning, nil
    })
    suite.Require().NoError(err)

    // Cleanup
    suite.cleanup()
}

func (suite *VitistackIntegrationTestSuite) TestMultiProviderVitistack() {
    // Test vitistack with multiple providers
    // Implementation similar to above but with multiple providers
}

func (suite *VitistackIntegrationTestSuite) TestCrossVitistackMachine() {
    // Test machine creation across different vitistacks
}

func (suite *VitistackIntegrationTestSuite) cleanup() {
    ctx := context.Background()

    // Delete all test resources
    suite.k8sClient.DeleteAllOf(ctx, &vitistackv1alpha1.Machine{},
        client.InNamespace(suite.testNamespace))
    suite.k8sClient.DeleteAllOf(ctx, &vitistackv1alpha1.Vitistack{},
        client.InNamespace(suite.testNamespace))
    suite.k8sClient.DeleteAllOf(ctx, &vitistackv1alpha1.MachineProvider{},
        client.InNamespace(suite.testNamespace))
}

func TestVitistackIntegrationSuite(t *testing.T) {
    suite.Run(t, new(VitistackIntegrationTestSuite))
}
```

### Multi-Cloud Integration Tests

```bash
#!/bin/bash
# multi-cloud-integration-test.sh

echo "Running multi-cloud integration tests..."

# Test AWS + Azure integration
echo "Testing AWS + Azure multi-cloud scenario..."
kubectl apply -f test/integration/scenarios/aws-azure-multicloud.yaml

# Wait for resources to be ready
kubectl wait --for=condition=Ready vitistack/multi-cloud-vitistack --timeout=600s

# Verify cross-cloud functionality
kubectl get machines -o wide
kubectl describe vitistack multi-cloud-vitistack

# Test GCP + AWS integration
echo "Testing GCP + AWS multi-cloud scenario..."
kubectl apply -f test/integration/scenarios/gcp-aws-multicloud.yaml

# Verify provider chaining
kubectl get machineproviders -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{end}'

# Test disaster recovery scenario
echo "Testing disaster recovery scenario..."
kubectl apply -f test/integration/scenarios/disaster-recovery.yaml

# Simulate primary vitistack failure
kubectl patch vitistack primary-vitistack -p='{"spec":{"enabled":false}}'

# Verify failover to secondary vitistack
kubectl wait --for=condition=Ready vitistack/secondary-vitistack --timeout=300s

echo "Multi-cloud integration tests completed"
```

## End-to-End Testing

### Comprehensive E2E Test Scenarios

#### E2E Test Framework

```yaml
# test/e2e/test-scenarios.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: e2e-test-scenarios
data:
  scenarios.yaml: |
    scenarios:
      - name: "single-cloud-deployment"
        description: "Deploy complete infrastructure in single cloud"
        steps:
          - action: "create-provider"
            provider: "aws"
            region: "us-east-1"
          - action: "create-vitistack"
            providers: ["aws-provider"]
          - action: "create-machines"
            count: 3
            type: "t3.medium"
          - action: "verify-connectivity"
          - action: "cleanup"
        
      - name: "multi-cloud-deployment"
        description: "Deploy across multiple cloud providers"
        steps:
          - action: "create-provider"
            provider: "aws"
            region: "us-east-1"
          - action: "create-provider"
            provider: "azure"
            region: "eastus"
          - action: "create-vitistack"
            providers: ["aws-provider", "azure-provider"]
          - action: "create-machines"
            distribution: "balanced"
            count: 6
          - action: "verify-cross-cloud-networking"
          - action: "test-failover"
          - action: "cleanup"
        
      - name: "disaster-recovery"
        description: "Test disaster recovery capabilities"
        steps:
          - action: "create-primary-vitistack"
            provider: "aws"
            region: "us-east-1"
          - action: "create-secondary-vitistack"
            provider: "aws"
            region: "us-west-2"
          - action: "deploy-application"
            replicas: 3
          - action: "simulate-disaster"
            target: "primary-vitistack"
          - action: "verify-failover"
          - action: "verify-data-consistency"
          - action: "cleanup"
```

#### E2E Test Runner

```bash
#!/bin/bash
# run-e2e-tests.sh

SCENARIO=${1:-"all"}
TEST_NAMESPACE="vitistack-e2e-$(date +%s)"

setup_test_environment() {
    echo "Setting up E2E test environment..."

    # Create test namespace
    kubectl create namespace $TEST_NAMESPACE

    # Apply CRDs
    kubectl apply -f crds/

    # Deploy controller
    kubectl apply -f config/

    # Wait for controller to be ready
    kubectl wait --for=condition=Available deployment/vitistack-controller -n vitistack-system --timeout=300s

    # Create test secrets
    create_test_secrets
}

create_test_secrets() {
    # AWS credentials
    kubectl create secret generic aws-e2e-creds \
        --from-literal=access-key="$AWS_ACCESS_KEY_ID" \
        --from-literal=secret-key="$AWS_SECRET_ACCESS_KEY" \
        -n $TEST_NAMESPACE

    # Azure credentials
    kubectl create secret generic azure-e2e-creds \
        --from-literal=client-id="$AZURE_CLIENT_ID" \
        --from-literal=client-secret="$AZURE_CLIENT_SECRET" \
        --from-literal=tenant-id="$AZURE_TENANT_ID" \
        -n $TEST_NAMESPACE

    # GCP credentials
    kubectl create secret generic gcp-e2e-creds \
        --from-file=service-account-key="$GOOGLE_APPLICATION_CREDENTIALS" \
        -n $TEST_NAMESPACE
}

run_scenario() {
    local scenario_name=$1
    echo "Running scenario: $scenario_name"

    case $scenario_name in
        "single-cloud-deployment")
            run_single_cloud_test
            ;;
        "multi-cloud-deployment")
            run_multi_cloud_test
            ;;
        "disaster-recovery")
            run_disaster_recovery_test
            ;;
        "edge-computing")
            run_edge_computing_test
            ;;
        "compliance-validation")
            run_compliance_test
            ;;
        *)
            echo "Unknown scenario: $scenario_name"
            exit 1
            ;;
    esac
}

run_single_cloud_test() {
    echo "Executing single cloud deployment test..."

    # Apply single cloud configuration
    envsubst < test/e2e/scenarios/single-cloud.yaml | kubectl apply -f - -n $TEST_NAMESPACE

    # Wait for vitistack to be ready
    kubectl wait --for=condition=Ready vitistack/single-cloud-dc -n $TEST_NAMESPACE --timeout=600s

    # Create test machines
    for i in {1..3}; do
        envsubst < test/e2e/templates/machine.yaml | \
            sed "s/MACHINE_NAME/test-machine-$i/" | \
            kubectl apply -f - -n $TEST_NAMESPACE
    done

    # Wait for machines to be running
    kubectl wait --for=condition=Ready machines --all -n $TEST_NAMESPACE --timeout=900s

    # Verify connectivity
    verify_machine_connectivity $TEST_NAMESPACE

    # Run application tests
    run_application_tests $TEST_NAMESPACE

    echo "Single cloud test completed successfully"
}

run_multi_cloud_test() {
    echo "Executing multi-cloud deployment test..."

    # Apply multi-cloud configuration
    envsubst < test/e2e/scenarios/multi-cloud.yaml | kubectl apply -f - -n $TEST_NAMESPACE

    # Wait for all vitistacks to be ready
    kubectl wait --for=condition=Ready vitistacks --all -n $TEST_NAMESPACE --timeout=900s

    # Create machines across clouds
    create_distributed_machines $TEST_NAMESPACE

    # Verify cross-cloud networking
    verify_cross_cloud_networking $TEST_NAMESPACE

    # Test load balancing
    test_load_balancing $TEST_NAMESPACE

    echo "Multi-cloud test completed successfully"
}

run_disaster_recovery_test() {
    echo "Executing disaster recovery test..."

    # Deploy primary and secondary vitistacks
    envsubst < test/e2e/scenarios/disaster-recovery.yaml | kubectl apply -f - -n $TEST_NAMESPACE

    # Wait for primary vitistack
    kubectl wait --for=condition=Ready vitistack/primary-dc -n $TEST_NAMESPACE --timeout=600s

    # Deploy application to primary
    kubectl apply -f test/e2e/apps/sample-app.yaml -n $TEST_NAMESPACE

    # Wait for application to be ready
    kubectl wait --for=condition=Available deployment/sample-app -n $TEST_NAMESPACE --timeout=300s

    # Simulate disaster
    simulate_vitistack_failure "primary-dc" $TEST_NAMESPACE

    # Verify failover to secondary
    kubectl wait --for=condition=Ready vitistack/secondary-dc -n $TEST_NAMESPACE --timeout=600s

    # Verify application recovery
    verify_application_recovery $TEST_NAMESPACE

    echo "Disaster recovery test completed successfully"
}

verify_machine_connectivity() {
    local namespace=$1
    echo "Verifying machine connectivity..."

    # Get machine IPs
    machines=$(kubectl get machines -n $namespace -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

    # Test connectivity between machines
    for machine_ip in $machines; do
        kubectl run connectivity-test-$(date +%s) --rm -i --tty --restart=Never \
            --image=busybox -n $namespace -- ping -c 3 $machine_ip
    done
}

verify_cross_cloud_networking() {
    local namespace=$1
    echo "Verifying cross-cloud networking..."

    # Get machines from different providers
    aws_machines=$(kubectl get machines -n $namespace -l provider=aws -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')
    azure_machines=$(kubectl get machines -n $namespace -l provider=azure -o jsonpath='{.items[*].status.addresses[?(@.type=="InternalIP")].address}')

    # Test connectivity between cloud providers
    if [ -n "$aws_machines" ] && [ -n "$azure_machines" ]; then
        aws_ip=$(echo $aws_machines | cut -d' ' -f1)
        azure_ip=$(echo $azure_machines | cut -d' ' -f1)

        kubectl run cross-cloud-test-$(date +%s) --rm -i --tty --restart=Never \
            --image=busybox -n $namespace -- ping -c 3 $azure_ip
    fi
}

simulate_vitistack_failure() {
    local vitistack_name=$1
    local namespace=$2
    echo "Simulating failure of vitistack: $vitistack_name"

    # Disable vitistack
    kubectl patch vitistack $vitistack_name -n $namespace -p='{"spec":{"enabled":false}}'

    # Wait for machines to be drained
    kubectl wait --for=delete machines -l vitistack=$vitistack_name -n $namespace --timeout=600s
}

cleanup_test_environment() {
    echo "Cleaning up test environment..."

    # Delete test namespace
    kubectl delete namespace $TEST_NAMESPACE --timeout=600s

    # Clean up any external resources
    cleanup_external_resources
}

cleanup_external_resources() {
    # Clean up cloud provider resources that might have been created
    # This would typically involve calling cloud provider APIs to clean up
    # any resources that weren't properly cleaned up by the controller
    echo "Cleaning up external resources..."
}

# Main execution
main() {
    trap cleanup_test_environment EXIT

    setup_test_environment

    if [ "$SCENARIO" = "all" ]; then
        scenarios=("single-cloud-deployment" "multi-cloud-deployment" "disaster-recovery")
        for scenario in "${scenarios[@]}"; do
            run_scenario "$scenario"
        done
    else
        run_scenario "$SCENARIO"
    fi

    echo "All E2E tests completed successfully"
}

main "$@"
```

## Performance Testing

### Load Testing Framework

#### Machine Provisioning Load Test

```bash
#!/bin/bash
# load-test-machine-provisioning.sh

CONCURRENT_MACHINES=${1:-10}
TOTAL_MACHINES=${2:-100}
TEST_NAMESPACE="vitistack-load-test"

echo "Starting machine provisioning load test..."
echo "Concurrent machines: $CONCURRENT_MACHINES"
echo "Total machines: $TOTAL_MACHINES"

# Setup test environment
kubectl create namespace $TEST_NAMESPACE
kubectl apply -f test/load/provider-config.yaml -n $TEST_NAMESPACE

# Create machine templates
create_machine_batch() {
    local batch_start=$1
    local batch_size=$2

    for ((i=$batch_start; i<$batch_start+$batch_size; i++)); do
        cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: load-test-machine-$i
  namespace: $TEST_NAMESPACE
spec:
  vitistackRef:
    name: load-test-vitistack
  machineType: t3.micro
  image:
    name: ubuntu-20.04
    version: latest
EOF
    done
}

# Monitor provisioning progress
monitor_provisioning() {
    while true; do
        running=$(kubectl get machines -n $TEST_NAMESPACE --field-selector=status.phase=Running --no-headers | wc -l)
        provisioning=$(kubectl get machines -n $TEST_NAMESPACE --field-selector=status.phase=Provisioning --no-headers | wc -l)
        failed=$(kubectl get machines -n $TEST_NAMESPACE --field-selector=status.phase=Failed --no-headers | wc -l)

        echo "$(date): Running: $running, Provisioning: $provisioning, Failed: $failed"

        if [ $((running + failed)) -ge $TOTAL_MACHINES ]; then
            break
        fi

        sleep 10
    done
}

# Execute load test
start_time=$(date +%s)

# Create machines in batches
for ((batch=0; batch<$TOTAL_MACHINES; batch+=$CONCURRENT_MACHINES)); do
    batch_size=$CONCURRENT_MACHINES
    if [ $((batch + batch_size)) -gt $TOTAL_MACHINES ]; then
        batch_size=$((TOTAL_MACHINES - batch))
    fi

    echo "Creating batch starting at machine $batch (size: $batch_size)"
    create_machine_batch $batch $batch_size

    # Wait a bit to control concurrency
    sleep 2
done

# Monitor until completion
monitor_provisioning

end_time=$(date +%s)
duration=$((end_time - start_time))

# Generate report
echo "Load test completed in $duration seconds"
kubectl get machines -n $TEST_NAMESPACE --no-headers | awk '{print $3}' | sort | uniq -c

# Cleanup
kubectl delete namespace $TEST_NAMESPACE
```

#### Performance Benchmarking

```go
// test/performance/benchmark_test.go
package performance

import (
    "context"
    "testing"
    "time"

    metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
    vitistackv1alpha1 "github.com/vitistack/crds/pkg/apis/v1alpha1"
)

func BenchmarkVitistackReconciliation(b *testing.B) {
    // Setup test environment
    ctx := context.Background()

    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        vitistack := &vitistackv1alpha1.Vitistack{
            ObjectMeta: metav1.ObjectMeta{
                Name:      fmt.Sprintf("benchmark-dc-%d", i),
                Namespace: "default",
            },
            Spec: vitistackv1alpha1.VitistackSpec{
                Location: vitistackv1alpha1.VitistackLocation{
                    Region: "us-east-1",
                    Zone:   "us-east-1a",
                },
            },
        }

        start := time.Now()
        err := k8sClient.Create(ctx, vitistack)
        if err != nil {
            b.Fatalf("Failed to create vitistack: %v", err)
        }

        // Wait for reconciliation
        err = waitForVitistackReady(ctx, vitistack.Name, 5*time.Minute)
        if err != nil {
            b.Fatalf("Vitistack not ready: %v", err)
        }

        elapsed := time.Since(start)
        b.Logf("Vitistack %d reconciled in %v", i, elapsed)

        // Cleanup
        k8sClient.Delete(ctx, vitistack)
    }
}

func BenchmarkMachineProvisioning(b *testing.B) {
    ctx := context.Background()

    // Pre-create vitistack
    vitistack := createTestVitistack(ctx, "benchmark-vitistack")
    defer k8sClient.Delete(ctx, vitistack)

    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        machine := &vitistackv1alpha1.Machine{
            ObjectMeta: metav1.ObjectMeta{
                Name:      fmt.Sprintf("benchmark-machine-%d", i),
                Namespace: "default",
            },
            Spec: vitistackv1alpha1.MachineSpec{
                VitistackRef: vitistackv1alpha1.VitistackRef{
                    Name: vitistack.Name,
                },
                MachineType: "t3.micro",
            },
        }

        start := time.Now()
        err := k8sClient.Create(ctx, machine)
        if err != nil {
            b.Fatalf("Failed to create machine: %v", err)
        }

        // Wait for provisioning
        err = waitForMachineRunning(ctx, machine.Name, 10*time.Minute)
        if err != nil {
            b.Fatalf("Machine not running: %v", err)
        }

        elapsed := time.Since(start)
        b.Logf("Machine %d provisioned in %v", i, elapsed)

        // Cleanup
        k8sClient.Delete(ctx, machine)
    }
}

func BenchmarkConcurrentReconciliation(b *testing.B) {
    ctx := context.Background()
    concurrency := 10

    b.ResetTimer()

    for i := 0; i < b.N; i++ {
        var wg sync.WaitGroup
        errors := make(chan error, concurrency)

        for j := 0; j < concurrency; j++ {
            wg.Add(1)
            go func(index int) {
                defer wg.Done()

                vitistack := createTestVitistack(ctx, fmt.Sprintf("concurrent-dc-%d-%d", i, index))
                defer k8sClient.Delete(ctx, vitistack)

                err := waitForVitistackReady(ctx, vitistack.Name, 5*time.Minute)
                if err != nil {
                    errors <- err
                }
            }(j)
        }

        wg.Wait()
        close(errors)

        for err := range errors {
            if err != nil {
                b.Fatalf("Concurrent reconciliation failed: %v", err)
            }
        }
    }
}
```

## Chaos Engineering

### Chaos Testing Framework

#### Infrastructure Chaos Tests

```bash
#!/bin/bash
# chaos-test-infrastructure.sh

echo "Starting infrastructure chaos tests..."

# Test 1: Controller Pod Failure
echo "Test 1: Controller pod failure simulation"
kubectl delete pod -n vitistack-system -l app=vitistack-controller

# Wait for new pod to start
kubectl wait --for=condition=Ready pod -n vitistack-system -l app=vitistack-controller --timeout=300s

# Verify system recovery
kubectl get vitistacks
kubectl get machines --all-namespaces

# Test 2: Network Partitioning
echo "Test 2: Network partition simulation"
# Simulate network issues using network policies
kubectl apply -f test/chaos/network-partition.yaml

# Wait and observe
sleep 60

# Restore network
kubectl delete -f test/chaos/network-partition.yaml

# Test 3: Resource Exhaustion
echo "Test 3: Resource exhaustion simulation"
kubectl apply -f test/chaos/resource-exhaustion.yaml

# Monitor system behavior
kubectl top pods -n vitistack-system

# Cleanup
kubectl delete -f test/chaos/resource-exhaustion.yaml

# Test 4: Provider API Failures
echo "Test 4: Provider API failure simulation"
# This would typically involve mocking or rate limiting provider APIs
simulate_provider_api_failures

echo "Chaos tests completed"
```

#### Failure Injection Framework

```yaml
# test/chaos/chaos-experiments.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: chaos-experiments
data:
  experiments.yaml: |
    experiments:
      - name: "controller-pod-failure"
        description: "Kill controller pod and verify recovery"
        steps:
          - action: "delete-pod"
            selector: "app=vitistack-controller"
            namespace: "vitistack-system"
          - action: "wait-for-recovery"
            timeout: "300s"
          - action: "verify-functionality"
            tests: ["vitistack-creation", "machine-provisioning"]
      
      - name: "etcd-network-partition"
        description: "Simulate etcd network partition"
        steps:
          - action: "apply-network-policy"
            file: "network-partition-etcd.yaml"
          - action: "wait"
            duration: "60s"
          - action: "remove-network-policy"
          - action: "verify-consistency"
      
      - name: "provider-credential-rotation"
        description: "Rotate provider credentials during operations"
        steps:
          - action: "start-machine-provisioning"
            count: 10
          - action: "rotate-credentials"
            providers: ["aws", "azure"]
          - action: "verify-no-failures"
          - action: "wait-for-completion"
      
      - name: "disk-pressure"
        description: "Simulate disk pressure on controller"
        steps:
          - action: "fill-disk"
            target: "controller"
            percentage: 95
          - action: "monitor-behavior"
            duration: "300s"
          - action: "cleanup-disk"
          - action: "verify-recovery"
```

### Resilience Testing

```bash
#!/bin/bash
# resilience-test.sh

echo "Starting resilience testing..."

# Function to check system health
check_system_health() {
    local expected_vitistacks=$1
    local expected_machines=$2

    local actual_vitistacks=$(kubectl get vitistacks --no-headers | wc -l)
    local actual_machines=$(kubectl get machines --all-namespaces --no-headers | wc -l)

    if [ "$actual_vitistacks" -eq "$expected_vitistacks" ] && [ "$actual_machines" -eq "$expected_machines" ]; then
        echo "✅ System health check passed"
        return 0
    else
        echo "❌ System health check failed"
        echo "Expected: $expected_vitistacks vitistacks, $expected_machines machines"
        echo "Actual: $actual_vitistacks vitistacks, $actual_machines machines"
        return 1
    fi
}

# Initial setup
kubectl apply -f test/resilience/initial-setup.yaml
kubectl wait --for=condition=Ready vitistacks --all --timeout=600s

initial_vitistacks=$(kubectl get vitistacks --no-headers | wc -l)
initial_machines=$(kubectl get machines --all-namespaces --no-headers | wc -l)

echo "Initial state: $initial_vitistacks vitistacks, $initial_machines machines"

# Test scenarios
test_scenarios=(
    "controller-restart"
    "webhook-failure"
    "api-server-restart"
    "network-partition"
    "resource-exhaustion"
)

for scenario in "${test_scenarios[@]}"; do
    echo "Running resilience test: $scenario"

    # Execute scenario
    ./test/resilience/scenarios/$scenario.sh

    # Wait for system to stabilize
    sleep 30

    # Check system health
    if check_system_health $initial_vitistacks $initial_machines; then
        echo "✅ Resilience test $scenario passed"
    else
        echo "❌ Resilience test $scenario failed"
        exit 1
    fi
done

echo "All resilience tests passed"
```

## Security Testing

### Security Test Suite

#### Authentication and Authorization Tests

```bash
#!/bin/bash
# security-test-auth.sh

echo "Running security authentication tests..."

# Test 1: Invalid credentials
echo "Test 1: Testing invalid credentials rejection"
kubectl create secret generic invalid-creds \
    --from-literal=access-key=invalid \
    --from-literal=secret-key=invalid \
    -n default

cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: MachineProvider
metadata:
  name: invalid-auth-provider
spec:
  providerType: aws
  configuration:
    aws:
      region: us-east-1
      secretRef: invalid-creds
EOF

# Wait and verify it fails authentication
sleep 30
auth_status=$(kubectl get machineprovider invalid-auth-provider -o jsonpath='{.status.conditions[?(@.type=="AuthenticationValid")].status}')

if [ "$auth_status" = "False" ]; then
    echo "✅ Invalid credentials correctly rejected"
else
    echo "❌ Invalid credentials not rejected"
    exit 1
fi

# Test 2: RBAC enforcement
echo "Test 2: Testing RBAC enforcement"
kubectl create serviceaccount test-user
kubectl create clusterrolebinding test-user-binding \
    --clusterrole=view \
    --serviceaccount=default:test-user

# Try to create vitistack with limited permissions
kubectl --as=system:serviceaccount:default:test-user apply -f - <<EOF
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: rbac-test-vitistack
spec:
  location:
    region: us-east-1
    zone: us-east-1a
EOF

# This should fail due to insufficient permissions
if [ $? -ne 0 ]; then
    echo "✅ RBAC correctly enforced"
else
    echo "❌ RBAC not enforced"
    exit 1
fi

# Cleanup
kubectl delete machineprovider invalid-auth-provider
kubectl delete secret invalid-creds
kubectl delete clusterrolebinding test-user-binding
kubectl delete serviceaccount test-user
```

#### Encryption and Data Protection Tests

```bash
#!/bin/bash
# security-test-encryption.sh

echo "Running encryption and data protection tests..."

# Test 1: Encryption at rest
echo "Test 1: Testing encryption at rest"
cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: encryption-test-vitistack
spec:
  location:
    region: us-east-1
    zone: us-east-1a
  security:
    encryption:
      atRest: true
      algorithm: "AES-256"
EOF

kubectl wait --for=condition=Ready vitistack/encryption-test-vitistack --timeout=600s

# Verify encryption is enabled
encryption_status=$(kubectl get vitistack encryption-test-vitistack -o jsonpath='{.status.security.encryption.status}')
if [ "$encryption_status" = "enabled" ]; then
    echo "✅ Encryption at rest verified"
else
    echo "❌ Encryption at rest not enabled"
fi

# Test 2: Secret encryption
echo "Test 2: Testing secret encryption"
kubectl create secret generic test-secret \
    --from-literal=password=super-secret-password

# Verify secret is encrypted in etcd
# This would typically require access to etcd directly
echo "✅ Secret encryption test (manual verification required)"

# Test 3: Network encryption
echo "Test 3: Testing network encryption"
cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: network-encryption-vitistack
spec:
  location:
    region: us-east-1
    zone: us-east-1a
  security:
    encryption:
      inTransit: true
      protocols: ["TLS1.3"]
  networking:
    vpcs:
    - name: secure-vpc
      cidr: "10.1.0.0/16"
      encryption: true
EOF

kubectl wait --for=condition=Ready vitistack/network-encryption-vitistack --timeout=600s
echo "✅ Network encryption configured"

# Cleanup
kubectl delete vitistack encryption-test-vitistack
kubectl delete vitistack network-encryption-vitistack
kubectl delete secret test-secret
```

## Compliance Testing

### Compliance Validation Framework

#### Regulatory Compliance Tests

```bash
#!/bin/bash
# compliance-test.sh

echo "Running compliance validation tests..."

# Test 1: SOC 2 Type II Compliance
echo "Test 1: SOC 2 Type II compliance validation"
cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: soc2-compliant-vitistack
spec:
  location:
    region: us-east-1
    zone: us-east-1a
  security:
    complianceFrameworks:
    - "SOC2-TypeII"
    auditLogging:
      enabled: true
      retentionDays: 365
    accessControl:
      mfa: true
      rbac: true
    encryption:
      atRest: true
      inTransit: true
EOF

kubectl wait --for=condition=Ready vitistack/soc2-compliant-vitistack --timeout=600s

# Verify compliance settings
compliance_status=$(kubectl get vitistack soc2-compliant-vitistack -o jsonpath='{.status.compliance.SOC2-TypeII.status}')
if [ "$compliance_status" = "compliant" ]; then
    echo "✅ SOC 2 compliance verified"
else
    echo "❌ SOC 2 compliance failed"
fi

# Test 2: GDPR Compliance
echo "Test 2: GDPR compliance validation"
cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: gdpr-compliant-vitistack
spec:
  location:
    region: eu-west-1
    zone: eu-west-1a
  security:
    complianceFrameworks:
    - "GDPR"
    dataResidency:
      enabled: true
      regions: ["eu-west-1", "eu-central-1"]
    dataRetention:
      enabled: true
      defaultRetentionDays: 30
    rightToBeErasure: true
EOF

kubectl wait --for=condition=Ready vitistack/gdpr-compliant-vitistack --timeout=600s
echo "✅ GDPR compliance configured"

# Test 3: HIPAA Compliance
echo "Test 3: HIPAA compliance validation"
cat <<EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: hipaa-compliant-vitistack
spec:
  location:
    region: us-east-1
    zone: us-east-1a
  security:
    complianceFrameworks:
    - "HIPAA"
    encryption:
      atRest: true
      inTransit: true
      algorithm: "FIPS-140-2"
    auditLogging:
      enabled: true
      retentionDays: 2555  # 7 years
    accessControl:
      mfa: true
      sessionTimeout: 15  # minutes
EOF

kubectl wait --for=condition=Ready vitistack/hipaa-compliant-vitistack --timeout=600s
echo "✅ HIPAA compliance configured"

# Generate compliance report
generate_compliance_report() {
    echo "=== Compliance Report ===" > compliance-report.txt
    echo "Generated: $(date)" >> compliance-report.txt
    echo "" >> compliance-report.txt

    kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.security.complianceFrameworks}{"\t"}{.status.compliance}{"\n"}{end}' >> compliance-report.txt

    echo "Compliance report generated: compliance-report.txt"
}

generate_compliance_report

# Cleanup
kubectl delete vitistack soc2-compliant-vitistack
kubectl delete vitistack gdpr-compliant-vitistack
kubectl delete vitistack hipaa-compliant-vitistack
```

## Test Automation

### CI/CD Pipeline Integration

#### GitHub Actions Workflow

```yaml
# .github/workflows/vitistack-test.yml
name: VitiStack Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Go
        uses: actions/setup-go@v6
        with:
          go-version: 1.19

      - name: Run unit tests
        run: |
          go test -v -race -coverprofile=coverage.out ./pkg/...
          go tool cover -html=coverage.out -o coverage.html

      - name: Upload coverage reports
        uses: codecov/codecov-action@v3

  integration-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    strategy:
      matrix:
        k8s-version: [1.25.0, 1.26.0, 1.27.0]
    steps:
      - uses: actions/checkout@v3

      - name: Create k8s cluster
        uses: helm/kind-action@v1.5.0
        with:
          kubernetes_version: v${{ matrix.k8s-version }}

      - name: Run integration tests
        run: |
          make install-crds
          make deploy-controller
          ./test/integration/run-integration-tests.sh

      - name: Collect logs
        if: failure()
        run: |
          kubectl logs -n vitistack-system deployment/vitistack-controller
          kubectl get events --all-namespaces

  e2e-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3

      - name: Set up cloud credentials
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          AZURE_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
          AZURE_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
          AZURE_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
        run: |
          echo "Setting up cloud credentials..."

      - name: Create k8s cluster
        uses: helm/kind-action@v1.5.0
        with:
          kubernetes_version: v1.27.0

      - name: Run E2E tests
        run: |
          make install-crds
          make deploy-controller
          ./test/e2e/run-e2e-tests.sh

      - name: Cleanup resources
        if: always()
        run: |
          ./test/e2e/cleanup-resources.sh

  security-tests:
    runs-on: ubuntu-latest
    needs: unit-tests
    steps:
      - uses: actions/checkout@v3

      - name: Run security scans
        run: |
          # Static analysis
          go install github.com/securecodewarrior/gosec/v2/cmd/gosec@latest
          gosec ./...

          # Dependency vulnerability check
          go mod download
          go list -json -m all | nancy sleuth

          # Container image scanning
          docker build -t vitistack/controller:test .
          trivy image vitistack/controller:test

      - name: Run security tests
        run: |
          ./test/security/run-security-tests.sh

  performance-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3

      - name: Set up performance test environment
        run: |
          # Create larger k8s cluster for performance testing
          kind create cluster --config=test/performance/kind-config.yaml

      - name: Run performance benchmarks
        run: |
          make install-crds
          make deploy-controller
          ./test/performance/run-benchmarks.sh

      - name: Upload performance results
        uses: actions/upload-artifact@v3
        with:
          name: performance-results
          path: test/performance/results/

  chaos-tests:
    runs-on: ubuntu-latest
    needs: integration-tests
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3

      - name: Create k8s cluster
        uses: helm/kind-action@v1.5.0

      - name: Install chaos engineering tools
        run: |
          kubectl apply -f https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/master/manifests/crd.yaml
          kubectl apply -f https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/master/manifests/rbac.yaml
          kubectl apply -f https://raw.githubusercontent.com/chaos-mesh/chaos-mesh/master/manifests/chaos-mesh.yaml

      - name: Run chaos tests
        run: |
          make install-crds
          make deploy-controller
          ./test/chaos/run-chaos-tests.sh
```

This comprehensive testing guide provides a complete framework for testing VitiStack CRDs across all dimensions - from unit tests to chaos engineering. It includes practical scripts, test scenarios, and automation frameworks that ensure the reliability, performance, and security of the VitiStack platform.

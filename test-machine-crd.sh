#!/bin/bash

# Test script to validate the Machine CRD

set -e

echo "🔍 Validating Machine CRD..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed"
    exit 1
fi

# Apply the CRD
echo "📋 Applying Machine CRD..."
kubectl apply -f crds/vitistack.io_machines.yaml

# Wait for CRD to be established
echo "⏳ Waiting for CRD to be established..."
kubectl wait --for condition=established --timeout=60s crd/machines.vitistack.io

# Test creating a machine resource
echo "🧪 Testing Machine resource creation..."
cat << EOF | kubectl apply -f -
apiVersion: vitistack.io/v1alpha1
kind: Machine
metadata:
  name: test-machine
  namespace: default
spec:
  name: test-vm
  instanceType: t3.micro
  os:
    family: linux
    distribution: ubuntu
    version: "22.04"
  providerConfig:
    name: aws
    region: us-west-2
EOF

# Verify the resource was created
echo "✅ Verifying Machine resource..."
kubectl get machine test-machine -o yaml

# Test the additional printer columns
echo "📊 Testing additional printer columns..."
kubectl get machines

# Clean up
echo "🧹 Cleaning up test resources..."
kubectl delete machine test-machine --ignore-not-found

echo "✅ Machine CRD validation completed successfully!"

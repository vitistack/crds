# VitiStack Deployment Automation Guide

This guide provides comprehensive CI/CD pipeline examples and GitOps configurations for automating VitiStack deployments across different environments.

## Overview

Deployment automation for VitiStack includes:

- CI/CD pipeline configurations for multiple platforms
- GitOps workflows with ArgoCD and Flux
- Infrastructure as Code patterns
- Automated testing and validation
- Environment promotion strategies
- Rollback procedures

## CI/CD Pipeline Examples

### GitHub Actions Workflow

```yaml
# .github/workflows/vitistack-deploy.yml
name: VitiStack Deployment Pipeline

on:
  push:
    branches: [main, develop]
    paths:
      - "crds/**"
      - "config/**"
      - "pkg/**"
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: vitistack/controller

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        k8s-version: [1.25.0, 1.26.0, 1.27.0]
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v4
        with:
          go-version-file: "go.mod"

      - name: Run tests
        run: |
          make test
          make test-integration

      - name: Create k8s cluster
        uses: helm/kind-action@v1.8.0
        with:
          kubernetes_version: v${{ matrix.k8s-version }}
          cluster_name: vitistack-test

      - name: Install CRDs and test
        run: |
          make install
          make deploy
          ./scripts/wait-for-deployment.sh
          make test-e2e

  build:
    needs: test
    runs-on: ubuntu-latest
    outputs:
      image: ${{ steps.image.outputs.image }}
      digest: ${{ steps.build.outputs.digest }}
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push image
        id: build
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

      - name: Output image
        id: image
        run: echo "image=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${{ steps.meta.outputs.version }}" >> $GITHUB_OUTPUT

  deploy-staging:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/develop'
    environment: staging
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.STAGING_KUBECONFIG }}

      - name: Deploy to staging
        run: |
          # Update image in kustomization
          cd config/staging
          kustomize edit set image controller=${{ needs.build.outputs.image }}@${{ needs.build.outputs.digest }}

          # Apply configuration
          kubectl apply -k .

          # Wait for deployment
          kubectl rollout status deployment/vitistack-controller -n vitistack-system --timeout=300s

      - name: Run smoke tests
        run: |
          ./scripts/smoke-test.sh staging

  deploy-production:
    needs: build
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    environment: production
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure kubectl
        uses: azure/k8s-set-context@v3
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.PRODUCTION_KUBECONFIG }}

      - name: Deploy to production
        run: |
          # Update image in kustomization
          cd config/production
          kustomize edit set image controller=${{ needs.build.outputs.image }}@${{ needs.build.outputs.digest }}

          # Apply with canary deployment
          kubectl apply -k . --dry-run=server
          kubectl apply -k .

          # Wait for deployment
          kubectl rollout status deployment/vitistack-controller -n vitistack-system --timeout=600s

      - name: Run production validation
        run: |
          ./scripts/production-validation.sh

      - name: Notify deployment
        uses: 8398a7/action-slack@v3
        with:
          status: ${{ job.status }}
          text: "VitiStack deployed to production: ${{ needs.build.outputs.image }}"
        env:
          SLACK_WEBHOOK_URL: ${{ secrets.SLACK_WEBHOOK }}

  security-scan:
    needs: build
    runs-on: ubuntu-latest
    steps:
      - name: Run Trivy vulnerability scanner
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: ${{ needs.build.outputs.image }}
          format: "sarif"
          output: "trivy-results.sarif"

      - name: Upload Trivy scan results
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: "trivy-results.sarif"
```

### GitLab CI/CD Pipeline

```yaml
# .gitlab-ci.yml
stages:
  - test
  - build
  - deploy-staging
  - deploy-production

variables:
  DOCKER_REGISTRY: registry.gitlab.com
  DOCKER_IMAGE: $DOCKER_REGISTRY/$CI_PROJECT_PATH/controller

.kubectl_config: &kubectl_config
  - mkdir -p ~/.kube
  - echo "$KUBECONFIG_CONTENT" | base64 -d > ~/.kube/config
  - chmod 600 ~/.kube/config

test:
  stage: test
  image: golang:1.21
  services:
    - docker:dind
  before_script:
    - apt-get update && apt-get install -y make curl
    - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    - chmod +x kubectl && mv kubectl /usr/local/bin/
  script:
    - make test
    - make test-integration
  coverage: '/coverage: \d+\.\d+% of statements/'
  artifacts:
    reports:
      coverage_report:
        coverage_format: cobertura
        path: coverage.xml

build:
  stage: build
  image: docker:latest
  services:
    - docker:dind
  before_script:
    - docker login -u $CI_REGISTRY_USER -p $CI_REGISTRY_PASSWORD $CI_REGISTRY
  script:
    - docker build -t $DOCKER_IMAGE:$CI_COMMIT_SHA .
    - docker tag $DOCKER_IMAGE:$CI_COMMIT_SHA $DOCKER_IMAGE:latest
    - docker push $DOCKER_IMAGE:$CI_COMMIT_SHA
    - docker push $DOCKER_IMAGE:latest
  only:
    - main
    - develop

deploy-staging:
  stage: deploy-staging
  image: bitnami/kubectl:latest
  environment:
    name: staging
    url: https://vitistack-staging.example.com
  before_script:
    - *kubectl_config
  script:
    - kubectl set image deployment/vitistack-controller controller=$DOCKER_IMAGE:$CI_COMMIT_SHA -n vitistack-system
    - kubectl rollout status deployment/vitistack-controller -n vitistack-system --timeout=300s
    - ./scripts/smoke-test.sh staging
  only:
    - develop

deploy-production:
  stage: deploy-production
  image: bitnami/kubectl:latest
  environment:
    name: production
    url: https://vitistack.example.com
  before_script:
    - *kubectl_config
  script:
    - kubectl set image deployment/vitistack-controller controller=$DOCKER_IMAGE:$CI_COMMIT_SHA -n vitistack-system
    - kubectl rollout status deployment/vitistack-controller -n vitistack-system --timeout=600s
    - ./scripts/production-validation.sh
  when: manual
  only:
    - main
```

### Azure DevOps Pipeline

```yaml
# azure-pipelines.yml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - crds/*
      - config/*
      - pkg/*

pool:
  vmImage: "ubuntu-latest"

variables:
  containerRegistry: "vitistack-acr"
  imageRepository: "vitistack/controller"
  dockerfilePath: "$(Build.SourcesDirectory)/Dockerfile"
  tag: "$(Build.BuildId)"

stages:
  - stage: Test
    displayName: Test stage
    jobs:
      - job: Test
        displayName: Test
        steps:
          - task: GoTool@0
            inputs:
              version: "1.21"

          - script: |
              make test
              make test-integration
            displayName: "Run tests"

          - task: PublishTestResults@2
            inputs:
              testResultsFormat: "JUnit"
              testResultsFiles: "**/test-results.xml"

  - stage: Build
    displayName: Build and push stage
    dependsOn: Test
    jobs:
      - job: Build
        displayName: Build
        steps:
          - task: Docker@2
            displayName: Build and push image
            inputs:
              command: buildAndPush
              repository: $(imageRepository)
              dockerfile: $(dockerfilePath)
              containerRegistry: $(containerRegistry)
              tags: |
                $(tag)
                latest

  - stage: DeployStaging
    displayName: Deploy to staging
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/develop'))
    jobs:
      - deployment: DeployStaging
        displayName: Deploy to staging
        environment: "staging.vitistack-system"
        strategy:
          runOnce:
            deploy:
              steps:
                - task: KubernetesManifest@0
                  displayName: Deploy to Kubernetes cluster
                  inputs:
                    action: deploy
                    manifests: |
                      $(Pipeline.Workspace)/manifests/deployment.yml
                      $(Pipeline.Workspace)/manifests/service.yml
                    containers: |
                      $(containerRegistry)/$(imageRepository):$(tag)

  - stage: DeployProduction
    displayName: Deploy to production
    dependsOn: Build
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: DeployProduction
        displayName: Deploy to production
        environment: "production.vitistack-system"
        strategy:
          runOnce:
            deploy:
              steps:
                - task: KubernetesManifest@0
                  displayName: Deploy to Kubernetes cluster
                  inputs:
                    action: deploy
                    manifests: |
                      $(Pipeline.Workspace)/manifests/deployment.yml
                      $(Pipeline.Workspace)/manifests/service.yml
                    containers: |
                      $(containerRegistry)/$(imageRepository):$(tag)
```

## GitOps Configurations

### ArgoCD Application

```yaml
# argocd/applications/vitistack-staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vitistack-staging
  namespace: argocd
  labels:
    environment: staging
    team: platform
spec:
  project: vitistack
  source:
    repoURL: https://github.com/company/vitistack-config
    targetRevision: develop
    path: environments/staging
    kustomize:
      images:
        - vitistack/controller:latest
  destination:
    server: https://kubernetes.default.svc
    namespace: vitistack-system
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10

---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: vitistack-production
  namespace: argocd
  labels:
    environment: production
    team: platform
spec:
  project: vitistack
  source:
    repoURL: https://github.com/company/vitistack-config
    targetRevision: main
    path: environments/production
    kustomize:
      images:
        - vitistack/controller:v1.0.0
  destination:
    server: https://kubernetes.default.svc
    namespace: vitistack-system
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 3
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
  revisionHistoryLimit: 10
```

### Flux Configuration

```yaml
# flux/clusters/staging/vitistack-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: vitistack-staging
  namespace: flux-system
spec:
  interval: 5m
  path: "./environments/staging"
  prune: true
  sourceRef:
    kind: GitRepository
    name: vitistack-config
  validation: client
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: vitistack-controller
      namespace: vitistack-system
  timeout: 10m

---
# flux/clusters/production/vitistack-kustomization.yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: vitistack-production
  namespace: flux-system
spec:
  interval: 10m
  path: "./environments/production"
  prune: true
  sourceRef:
    kind: GitRepository
    name: vitistack-config
  validation: client
  healthChecks:
    - apiVersion: apps/v1
      kind: Deployment
      name: vitistack-controller
      namespace: vitistack-system
  timeout: 15m
  dependsOn:
    - name: vitistack-crds
```

### Git Repository Structure

```
vitistack-config/
├── base/
│   ├── crds/
│   │   ├── kustomization.yaml
│   │   └── vitistack-crds.yaml
│   ├── controller/
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── rbac.yaml
│   │   └── kustomization.yaml
│   └── monitoring/
│       ├── prometheus-rules.yaml
│       ├── grafana-dashboard.yaml
│       └── kustomization.yaml
├── environments/
│   ├── staging/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── config-patch.yaml
│   │   └── resource-quotas.yaml
│   └── production/
│       ├── kustomization.yaml
│       ├── namespace.yaml
│       ├── config-patch.yaml
│       ├── pdb.yaml
│       └── hpa.yaml
└── overlays/
    ├── aws/
    ├── azure/
    └── gcp/
```

## Infrastructure as Code Patterns

### Terraform Integration

```hcl
# terraform/modules/vitistack/main.tf
resource "kubernetes_namespace" "vitistack_system" {
  metadata {
    name = "vitistack-system"
    labels = {
      "app.kubernetes.io/name"     = "vitistack"
      "app.kubernetes.io/instance" = "vitistack-controller"
    }
  }
}

resource "kubernetes_secret" "aws_credentials" {
  metadata {
    name      = "aws-credentials"
    namespace = kubernetes_namespace.vitistack_system.metadata[0].name
  }

  data = {
    access-key-id     = var.aws_access_key_id
    secret-access-key = var.aws_secret_access_key
  }

  type = "Opaque"
}

resource "helm_release" "vitistack" {
  name       = "vitistack"
  repository = "https://charts.vitistack.io"
  chart      = "vitistack-controller"
  version    = var.vitistack_version
  namespace  = kubernetes_namespace.vitistack_system.metadata[0].name

  values = [
    templatefile("${path.module}/values.yaml.tpl", {
      image_tag           = var.image_tag
      replicas           = var.replicas
      resource_requests  = var.resource_requests
      resource_limits    = var.resource_limits
      aws_region         = var.aws_region
    })
  ]

  depends_on = [
    kubernetes_secret.aws_credentials
  ]
}

# Create initial datacenter
resource "kubectl_manifest" "datacenter" {
  yaml_body = templatefile("${path.module}/datacenter.yaml.tpl", {
    name              = var.datacenter_name
    region            = var.aws_region
    vpc_cidr          = var.vpc_cidr
    availability_zones = var.availability_zones
  })

  depends_on = [helm_release.vitistack]
}
```

### Pulumi Configuration

```typescript
// pulumi/index.ts
import * as k8s from "@pulumi/kubernetes";
import * as aws from "@pulumi/aws";

// Create namespace
const vitistackNamespace = new k8s.core.v1.Namespace("vitistack-system", {
  metadata: {
    name: "vitistack-system",
    labels: {
      "app.kubernetes.io/name": "vitistack",
    },
  },
});

// Create AWS credentials secret
const awsCredentialsSecret = new k8s.core.v1.Secret("aws-credentials", {
  metadata: {
    name: "aws-credentials",
    namespace: vitistackNamespace.metadata.name,
  },
  stringData: {
    "access-key-id": process.env.AWS_ACCESS_KEY_ID!,
    "secret-access-key": process.env.AWS_SECRET_ACCESS_KEY!,
  },
});

// Deploy VitiStack controller
const vitistackController = new k8s.helm.v3.Release("vitistack-controller", {
  chart: "vitistack-controller",
  repositoryOpts: {
    repo: "https://charts.vitistack.io",
  },
  namespace: vitistackNamespace.metadata.name,
  values: {
    image: {
      tag: "v1.0.0",
    },
    replicaCount: 3,
    resources: {
      requests: {
        cpu: "200m",
        memory: "256Mi",
      },
      limits: {
        cpu: "1000m",
        memory: "1Gi",
      },
    },
  },
});

// Create datacenter
const datacenter = new k8s.apiextensions.CustomResource(
  "aws-datacenter",
  {
    apiVersion: "vitistack.io/v1alpha1",
    kind: "Datacenter",
    metadata: {
      name: "aws-production",
      namespace: vitistackNamespace.metadata.name,
    },
    spec: {
      region: "us-west-2",
      description: "Production datacenter in AWS US West 2",
      machineProviders: [
        {
          name: "aws-ec2-provider",
          priority: 1,
        },
      ],
      kubernetesProviders: [
        {
          name: "aws-eks-provider",
          priority: 1,
        },
      ],
    },
  },
  { dependsOn: [vitistackController] }
);
```

## Deployment Scripts

### Deployment Automation Script

```bash
#!/bin/bash
# scripts/deploy.sh

set -euo pipefail

ENVIRONMENT=${1:-staging}
NAMESPACE="vitistack-system"
TIMEOUT=600

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Validate environment
case $ENVIRONMENT in
    staging|production)
        log "Deploying to $ENVIRONMENT environment"
        ;;
    *)
        error "Invalid environment: $ENVIRONMENT. Must be 'staging' or 'production'"
        ;;
esac

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."

    command -v kubectl >/dev/null 2>&1 || error "kubectl is required but not installed"
    command -v kustomize >/dev/null 2>&1 || error "kustomize is required but not installed"

    # Check cluster connectivity
    kubectl cluster-info >/dev/null 2>&1 || error "Cannot connect to Kubernetes cluster"

    # Check if namespace exists
    if ! kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
        log "Creating namespace $NAMESPACE"
        kubectl create namespace $NAMESPACE
    fi
}

# Pre-deployment validation
pre_deployment_validation() {
    log "Running pre-deployment validation..."

    # Validate CRDs
    log "Validating CRDs..."
    kubectl apply --dry-run=server -f crds/ || error "CRD validation failed"

    # Validate configuration
    log "Validating configuration..."
    kustomize build config/$ENVIRONMENT | kubectl apply --dry-run=server -f - || error "Configuration validation failed"

    # Check resource quotas
    if [ "$ENVIRONMENT" = "production" ]; then
        log "Checking resource quotas for production..."
        # Add resource quota checks here
    fi
}

# Deploy CRDs
deploy_crds() {
    log "Deploying CRDs..."
    kubectl apply -f crds/

    # Wait for CRDs to be established
    log "Waiting for CRDs to be established..."
    kubectl wait --for condition=established --timeout=60s crd/datacenters.vitistack.io
    kubectl wait --for condition=established --timeout=60s crd/machineproviders.vitistack.io
    kubectl wait --for condition=established --timeout=60s crd/kubernetesproviders.vitistack.io
    kubectl wait --for condition=established --timeout=60s crd/machines.vitistack.io
}

# Deploy controller
deploy_controller() {
    log "Deploying VitiStack controller..."

    # Apply configuration
    kustomize build config/$ENVIRONMENT | kubectl apply -f -

    # Wait for deployment to be ready
    log "Waiting for controller deployment to be ready..."
    kubectl rollout status deployment/vitistack-controller -n $NAMESPACE --timeout=${TIMEOUT}s

    # Wait for webhook to be ready
    log "Waiting for webhook to be ready..."
    kubectl wait --for=condition=Available deployment/vitistack-controller -n $NAMESPACE --timeout=300s
}

# Post-deployment validation
post_deployment_validation() {
    log "Running post-deployment validation..."

    # Check controller logs for errors
    log "Checking controller logs..."
    if kubectl logs -n $NAMESPACE deployment/vitistack-controller --tail=50 | grep -i error; then
        warn "Found errors in controller logs"
    fi

    # Validate webhook
    log "Validating webhook..."
    kubectl get validatingwebhookconfiguration vitistack-validating-webhook-configuration || error "Webhook configuration not found"

    # Test basic functionality
    log "Testing basic functionality..."
    ./scripts/smoke-test.sh $ENVIRONMENT || error "Smoke test failed"
}

# Rollback function
rollback() {
    log "Rolling back deployment..."
    kubectl rollout undo deployment/vitistack-controller -n $NAMESPACE
    kubectl rollout status deployment/vitistack-controller -n $NAMESPACE --timeout=300s
}

# Main deployment flow
main() {
    log "Starting VitiStack deployment to $ENVIRONMENT"

    # Set up error handling
    trap 'error "Deployment failed. Check logs above."' ERR

    check_prerequisites
    pre_deployment_validation
    deploy_crds
    deploy_controller
    post_deployment_validation

    log "Deployment to $ENVIRONMENT completed successfully!"
}

# Handle script arguments
case "${1:-deploy}" in
    deploy)
        main
        ;;
    rollback)
        rollback
        ;;
    validate)
        check_prerequisites
        pre_deployment_validation
        log "Validation completed successfully!"
        ;;
    *)
        echo "Usage: $0 [staging|production] [deploy|rollback|validate]"
        exit 1
        ;;
esac
```

### Smoke Test Script

```bash
#!/bin/bash
# scripts/smoke-test.sh

set -euo pipefail

ENVIRONMENT=${1:-staging}
NAMESPACE="vitistack-system"
TEST_NAMESPACE="vitistack-smoke-test-$(date +%s)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

cleanup() {
    log "Cleaning up smoke test resources..."
    kubectl delete namespace $TEST_NAMESPACE --ignore-not-found=true
}

# Set up cleanup on exit
trap cleanup EXIT

smoke_test() {
    log "Starting smoke test for $ENVIRONMENT environment"

    # Create test namespace
    kubectl create namespace $TEST_NAMESPACE

    # Test 1: Controller health
    log "Test 1: Checking controller health..."
    kubectl get deployment vitistack-controller -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' | grep -q "3" || error "Controller not healthy"

    # Test 2: CRD availability
    log "Test 2: Checking CRD availability..."
    kubectl get crd datacenters.vitistack.io >/dev/null 2>&1 || error "Datacenter CRD not available"
    kubectl get crd machineproviders.vitistack.io >/dev/null 2>&1 || error "MachineProvider CRD not available"
    kubectl get crd kubernetesproviders.vitistack.io >/dev/null 2>&1 || error "KubernetesProvider CRD not available"
    kubectl get crd machines.vitistack.io >/dev/null 2>&1 || error "Machine CRD not available"

    # Test 3: Webhook functionality
    log "Test 3: Testing webhook functionality..."
    cat <<EOF | kubectl apply -f - || error "Webhook validation failed"
apiVersion: vitistack.io/v1alpha1
kind: Datacenter
metadata:
  name: smoke-test-datacenter
  namespace: $TEST_NAMESPACE
spec:
  region: us-west-2
  description: "Smoke test datacenter"
  machineProviders: []
  kubernetesProviders: []
EOF

    # Test 4: Controller reconciliation
    log "Test 4: Testing controller reconciliation..."
    sleep 5
    kubectl get datacenter smoke-test-datacenter -n $TEST_NAMESPACE -o jsonpath='{.status.phase}' | grep -q "Ready\|Pending" || error "Controller not reconciling"

    # Test 5: Metrics endpoint
    log "Test 5: Checking metrics endpoint..."
    kubectl port-forward -n $NAMESPACE deployment/vitistack-controller 8080:8080 &
    PORTFORWARD_PID=$!
    sleep 5
    curl -sf http://localhost:8080/metrics >/dev/null || error "Metrics endpoint not available"
    kill $PORTFORWARD_PID

    log "All smoke tests passed!"
}

smoke_test
```

### Production Validation Script

```bash
#!/bin/bash
# scripts/production-validation.sh

set -euo pipefail

NAMESPACE="vitistack-system"

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1\033[0m"
    exit 1
}

production_validation() {
    log "Starting production validation..."

    # Check controller replicas
    log "Validating controller replicas..."
    REPLICAS=$(kubectl get deployment vitistack-controller -n $NAMESPACE -o jsonpath='{.spec.replicas}')
    [[ $REPLICAS -ge 3 ]] || error "Production should have at least 3 controller replicas"

    # Check resource limits
    log "Validating resource limits..."
    CPU_LIMIT=$(kubectl get deployment vitistack-controller -n $NAMESPACE -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}')
    [[ -n "$CPU_LIMIT" ]] || error "CPU limits must be set in production"

    # Check PodDisruptionBudget
    log "Validating PodDisruptionBudget..."
    kubectl get pdb vitistack-controller-pdb -n $NAMESPACE >/dev/null 2>&1 || error "PodDisruptionBudget must be configured"

    # Check monitoring
    log "Validating monitoring setup..."
    kubectl get servicemonitor vitistack-controller -n $NAMESPACE >/dev/null 2>&1 || error "ServiceMonitor must be configured"

    # Check security policies
    log "Validating security policies..."
    kubectl get networkpolicy -n $NAMESPACE | grep -q vitistack || error "NetworkPolicies must be configured"

    # Validate SSL/TLS
    log "Validating webhook SSL configuration..."
    kubectl get secret webhook-server-certs -n $NAMESPACE >/dev/null 2>&1 || error "Webhook SSL certificates not found"

    log "Production validation completed successfully!"
}

production_validation
```

## Helm Charts

### Chart Structure

```
charts/vitistack-controller/
├── Chart.yaml
├── values.yaml
├── values-production.yaml
├── templates/
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── rbac.yaml
│   ├── webhook.yaml
│   ├── pdb.yaml
│   ├── hpa.yaml
│   ├── servicemonitor.yaml
│   └── networkpolicy.yaml
└── crds/
    ├── datacenters.yaml
    ├── machineproviders.yaml
    ├── kubernetesproviders.yaml
    └── machines.yaml
```

### Chart.yaml

```yaml
apiVersion: v2
name: vitistack-controller
description: A Helm chart for VitiStack CRD Controller
type: application
version: 1.0.0
appVersion: "v1.0.0"
home: https://github.com/company/vitistack
sources:
  - https://github.com/company/vitistack
maintainers:
  - name: Platform Team
    email: platform@company.com
keywords:
  - infrastructure
  - kubernetes
  - multi-cloud
  - automation
```

### values.yaml

```yaml
# Default values for vitistack-controller
replicaCount: 1

image:
  repository: vitistack/controller
  pullPolicy: IfNotPresent
  tag: ""

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532

securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true

service:
  type: ClusterIP
  port: 443
  targetPort: 9443

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 100m
    memory: 128Mi

autoscaling:
  enabled: false
  minReplicas: 1
  maxReplicas: 10
  targetCPUUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

podDisruptionBudget:
  enabled: false
  minAvailable: 1

monitoring:
  enabled: false
  serviceMonitor:
    enabled: false
    interval: 30s
    path: /metrics
    port: metrics

networkPolicy:
  enabled: false

webhook:
  failurePolicy: Fail
  namespaceSelector: {}
  timeoutSeconds: 10

metrics:
  enabled: true
  port: 8080

healthcheck:
  enabled: true
  port: 8081
```

### values-production.yaml

```yaml
replicaCount: 3

image:
  pullPolicy: Always

podSecurityContext:
  runAsNonRoot: true
  runAsUser: 65532
  fsGroup: 65532

resources:
  limits:
    cpu: 1000m
    memory: 1Gi
  requests:
    cpu: 200m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70

podDisruptionBudget:
  enabled: true
  minAvailable: 2

monitoring:
  enabled: true
  serviceMonitor:
    enabled: true
    interval: 15s

networkPolicy:
  enabled: true

affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - vitistack-controller
          topologyKey: kubernetes.io/hostname
```

## Environment Promotion Strategy

### Staging to Production Promotion

```bash
#!/bin/bash
# scripts/promote-to-production.sh

set -euo pipefail

STAGING_TAG=${1:-latest}
PRODUCTION_TAG=${2:-}

log() {
    echo -e "\033[0;32m[$(date +'%Y-%m-%d %H:%M:%S')] $1\033[0m"
}

error() {
    echo -e "\033[0;31m[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1\033[0m"
    exit 1
}

# Generate production tag if not provided
if [[ -z "$PRODUCTION_TAG" ]]; then
    PRODUCTION_TAG="v$(date +%Y%m%d)-$(git rev-parse --short HEAD)"
fi

promote_to_production() {
    log "Promoting $STAGING_TAG to production as $PRODUCTION_TAG"

    # 1. Validate staging deployment
    log "Validating staging deployment..."
    ./scripts/smoke-test.sh staging || error "Staging validation failed"

    # 2. Tag image for production
    log "Tagging image for production..."
    docker pull vitistack/controller:$STAGING_TAG
    docker tag vitistack/controller:$STAGING_TAG vitistack/controller:$PRODUCTION_TAG
    docker push vitistack/controller:$PRODUCTION_TAG

    # 3. Update production configuration
    log "Updating production configuration..."
    cd config/production
    kustomize edit set image controller=vitistack/controller:$PRODUCTION_TAG

    # 4. Create pull request for production deployment
    log "Creating pull request for production deployment..."
    git checkout -b "promote-$PRODUCTION_TAG"
    git add config/production/kustomization.yaml
    git commit -m "Promote $STAGING_TAG to production as $PRODUCTION_TAG"
    git push origin "promote-$PRODUCTION_TAG"

    # Create PR using GitHub CLI if available
    if command -v gh >/dev/null 2>&1; then
        gh pr create \
            --title "Promote to Production: $PRODUCTION_TAG" \
            --body "Promoting staging deployment $STAGING_TAG to production as $PRODUCTION_TAG" \
            --base main \
            --head "promote-$PRODUCTION_TAG"
    fi

    log "Promotion process completed. Please review and merge the PR to deploy to production."
}

promote_to_production
```

This deployment automation guide provides comprehensive CI/CD pipeline examples, GitOps configurations, and deployment scripts that enable reliable, automated deployment of VitiStack across different environments. The configurations support multiple platforms and include proper validation, monitoring, and rollback procedures.

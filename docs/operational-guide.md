# VitiStack Operational Guide

## Overview

This guide provides comprehensive operational procedures, troubleshooting workflows, monitoring strategies, and best practices for managing VitiStack CRDs in production environments. It covers day-to-day operations, incident response, performance optimization, and maintenance procedures.

## Table of Contents

- [System Monitoring](#system-monitoring)
- [Troubleshooting Workflows](#troubleshooting-workflows)
- [Performance Optimization](#performance-optimization)
- [Backup and Recovery](#backup-and-recovery)
- [Security Operations](#security-operations)
- [Capacity Planning](#capacity-planning)
- [Incident Response](#incident-response)
- [Maintenance Procedures](#maintenance-procedures)
- [Alerting and Notifications](#alerting-and-notifications)
- [Health Check Procedures](#health-check-procedures)

## System Monitoring

### Key Metrics to Monitor

#### Vitistack Metrics

```bash
# Check vitistack health status
kubectl get vitistacks -o custom-columns=NAME:.metadata.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status

# Monitor resource utilization
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.resourceUsage.cpuCoresUsed}/{.status.resourceUsage.cpuCoresTotal}{"\t"}{.status.resourceUsage.memoryGBUsed}/{.status.resourceUsage.memoryGBTotal}{"\n"}{end}'

# Check provider health
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.providerStatuses[*]}{"\t"}{.name}{"\t"}{.healthy}{"\t"}{.message}{"\n"}{end}{end}'
```

#### Machine Provider Metrics

```bash
# Monitor machine provider status
kubectl get machineproviders -o custom-columns=NAME:.metadata.name,TYPE:.spec.providerType,PHASE:.status.phase,AVAILABLE:.status.availableMachines,TOTAL:.status.totalMachines

# Check authentication health
kubectl get machineproviders -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.conditions[?(@.type=="AuthenticationValid")].status}{"\t"}{.status.conditions[?(@.type=="AuthenticationValid")].message}{"\n"}{end}'

# Monitor quota usage
kubectl get machineproviders -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.quotaUsage.instancesUsed}/{.status.quotaUsage.instancesLimit}{"\n"}{end}'
```

#### Machine Metrics

```bash
# Check machine health across all namespaces
kubectl get machines --all-namespaces -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,NODE:.status.nodeRef.name

# Monitor machine provisioning times
kubectl get machines -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.provisioningStartTime}{"\t"}{.status.provisioningCompletionTime}{"\n"}{end}'

# Check failed machines
kubectl get machines --all-namespaces --field-selector=status.phase=Failed
```

#### Kubernetes Provider Metrics

```bash
# Monitor cluster health
kubectl get kubernetesproviders -o custom-columns=NAME:.metadata.name,TYPE:.spec.providerType,CLUSTERS:.status.activeClusters,HEALTH:.status.conditions[?(@.type=="Healthy")].status

# Check cluster connectivity
kubectl get kubernetesproviders -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.connectivity.lastSuccessfulConnection}{"\t"}{.status.connectivity.consecutiveFailures}{"\n"}{end}'
```

### Monitoring Stack Configuration

#### Prometheus Configuration

```yaml
# prometheus-vitistack-rules.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vitistack-monitoring
  namespace: vitistack-system
spec:
  groups:
    - name: vitistack.vitistack
      rules:
        - alert: VitistackNotReady
          expr: vitistack_vitistack_ready != 1
          for: 5m
          labels:
            severity: critical
          annotations:
            summary: "Vitistack {{ $labels.vitistack }} is not ready"
            description: "Vitistack {{ $labels.vitistack }} has been not ready for more than 5 minutes"

        - alert: VitistackResourceUsageHigh
          expr: (vitistack_vitistack_cpu_used / vitistack_vitistack_cpu_total) > 0.85
          for: 10m
          labels:
            severity: warning
          annotations:
            summary: "High CPU usage in vitistack {{ $labels.vitistack }}"

        - alert: VitistackProviderDown
          expr: vitistack_vitistack_provider_healthy == 0
          for: 2m
          labels:
            severity: critical
          annotations:
            summary: "Provider {{ $labels.provider }} in vitistack {{ $labels.vitistack }} is down"

    - name: vitistack.machines
      rules:
        - alert: MachineProvisioningFailed
          expr: increase(vitistack_machine_provisioning_failures_total[5m]) > 0
          labels:
            severity: warning
          annotations:
            summary: "Machine provisioning failures detected"

        - alert: MachineStuckProvisioning
          expr: vitistack_machine_provisioning_duration_seconds > 1800
          labels:
            severity: warning
          annotations:
            summary: "Machine {{ $labels.machine }} stuck in provisioning for over 30 minutes"

    - name: vitistack.providers
      rules:
        - alert: ProviderQuotaExhausted
          expr: (vitistack_provider_quota_used / vitistack_provider_quota_limit) > 0.95
          labels:
            severity: critical
          annotations:
            summary: "Provider {{ $labels.provider }} quota nearly exhausted"
```

#### Grafana Dashboard Configuration

```json
{
  "dashboard": {
    "title": "VitiStack Operations Dashboard",
    "panels": [
      {
        "title": "Vitistack Health Overview",
        "type": "stat",
        "targets": [
          {
            "expr": "count(vitistack_vitistack_ready == 1)",
            "legendFormat": "Ready Vitistacks"
          },
          {
            "expr": "count(vitistack_vitistack_ready == 0)",
            "legendFormat": "Failed Vitistacks"
          }
        ]
      },
      {
        "title": "Resource Utilization by Vitistack",
        "type": "bargauge",
        "targets": [
          {
            "expr": "vitistack_vitistack_cpu_used / vitistack_vitistack_cpu_total * 100",
            "legendFormat": "CPU % - {{ vitistack }}"
          },
          {
            "expr": "vitistack_vitistack_memory_used / vitistack_vitistack_memory_total * 100",
            "legendFormat": "Memory % - {{ vitistack }}"
          }
        ]
      },
      {
        "title": "Machine Provisioning Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "rate(vitistack_machine_provisioning_total[5m])",
            "legendFormat": "Provisioning Rate"
          },
          {
            "expr": "rate(vitistack_machine_provisioning_failures_total[5m])",
            "legendFormat": "Failure Rate"
          }
        ]
      }
    ]
  }
}
```

## Troubleshooting Workflows

### Common Issues and Resolution

#### 1. Vitistack Not Ready

**Symptoms:**

- Vitistack phase stuck in "Initializing" or "Provisioning"
- Ready condition false
- Machines cannot be provisioned

**Diagnosis Steps:**

```bash
# Check vitistack status
kubectl describe vitistack <vitistack-name>

# Check events
kubectl get events --field-selector involvedObject.name=<vitistack-name>

# Verify provider references
kubectl get machineproviders,kubernetesproviders -n <namespace>

# Check controller logs
kubectl logs -n vitistack-system deployment/vitistack-controller
```

**Common Causes and Solutions:**

1. **Invalid Provider References**

   ```bash
   # Verify providers exist
   kubectl get machineprovider <provider-name> -n <namespace>

   # Check provider status
   kubectl describe machineprovider <provider-name>
   ```

2. **Network Configuration Issues**

   ```bash
   # Validate CIDR blocks don't overlap
   kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.networking.vpcs[*].cidr}{"\n"}{end}'

   # Check subnet configurations
   kubectl describe vitistack <name> | grep -A 10 networking
   ```

3. **Resource Quota Conflicts**
   ```bash
   # Check current usage vs limits
   kubectl get vitistack <name> -o jsonpath='{.status.resourceUsage}'
   ```

#### 2. Machine Provisioning Failures

**Symptoms:**

- Machines stuck in "Provisioning" phase
- High provisioning failure rate
- Timeout errors

**Diagnosis Steps:**

```bash
# Check machine status
kubectl describe machine <machine-name>

# Check provider capacity
kubectl get machineprovider <provider-name> -o jsonpath='{.status.capacity}'

# Verify authentication
kubectl get machineprovider <provider-name> -o jsonpath='{.status.conditions[?(@.type=="AuthenticationValid")]}'

# Check cloud provider limits
kubectl logs -n vitistack-system deployment/vitistack-controller | grep -i "quota\|limit\|capacity"
```

**Resolution Strategies:**

1. **Authentication Issues**

   ```bash
   # Rotate credentials
   kubectl create secret generic <provider-secret> \
     --from-literal=access-key=<new-key> \
     --from-literal=secret-key=<new-secret> \
     --dry-run=client -o yaml | kubectl apply -f -

   # Restart controller to pick up new credentials
   kubectl rollout restart deployment/vitistack-controller -n vitistack-system
   ```

2. **Capacity Issues**

   ```bash
   # Scale down unused machines
   kubectl delete machine <unused-machine>

   # Add additional providers
   kubectl apply -f additional-provider.yaml
   ```

3. **Network Issues**
   ```bash
   # Check VPC/subnet availability
   # Verify security group rules
   # Test connectivity from controller
   ```

#### 3. Provider Authentication Failures

**Symptoms:**

- AuthenticationValid condition false
- API calls failing with 401/403 errors
- Provider phase stuck in "Configuring"

**Diagnosis:**

```bash
# Check authentication status
kubectl get machineprovider <name> -o jsonpath='{.status.conditions[?(@.type=="AuthenticationValid")]}'

# Verify secret exists and has correct keys
kubectl get secret <auth-secret> -o jsonpath='{.data}' | base64 -d

# Check provider-specific requirements
kubectl describe machineprovider <name>
```

**Resolution:**

```bash
# Update credentials
kubectl patch secret <auth-secret> -p='{"data":{"access-key":"<base64-encoded-key>"}}'

# Force reconciliation
kubectl annotate machineprovider <name> vitistack.io/force-sync="$(date)"
```

### Troubleshooting Toolkit

#### Essential Commands

```bash
#!/bin/bash
# vitistack-debug.sh - Comprehensive debugging script

echo "=== VitiStack System Status ==="

echo "Vitistacks:"
kubectl get vitistacks -o wide

echo -e "\nMachine Providers:"
kubectl get machineproviders -o wide

echo -e "\nKubernetes Providers:"
kubectl get kubernetesproviders -o wide

echo -e "\nMachines:"
kubectl get machines --all-namespaces

echo -e "\nController Status:"
kubectl get pods -n vitistack-system

echo -e "\nRecent Events:"
kubectl get events --sort-by=.metadata.creationTimestamp | tail -20

echo -e "\nController Logs (last 50 lines):"
kubectl logs -n vitistack-system deployment/vitistack-controller --tail=50
```

#### Health Check Script

```bash
#!/bin/bash
# vitistack-healthcheck.sh

check_component() {
    local component=$1
    local namespace=${2:-default}

    echo "Checking $component..."

    if kubectl get $component -n $namespace &>/dev/null; then
        local ready=$(kubectl get $component -n $namespace -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}')
        if [[ "$ready" == *"True"* ]]; then
            echo "✅ $component is healthy"
            return 0
        else
            echo "❌ $component is not ready"
            return 1
        fi
    else
        echo "❌ $component not found"
        return 1
    fi
}

echo "=== VitiStack Health Check ==="

check_component "vitistacks"
check_component "machineproviders"
check_component "kubernetesproviders"
check_component "machines"

echo -e "\n=== Controller Health ==="
if kubectl get pods -n vitistack-system -l app=vitistack-controller --field-selector=status.phase=Running &>/dev/null; then
    echo "✅ Controller is running"
else
    echo "❌ Controller is not running"
fi
```

## Performance Optimization

### Controller Performance Tuning

#### Resource Allocation

```yaml
# controller-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vitistack-controller
  namespace: vitistack-system
spec:
  replicas: 3 # Scale for high availability
  template:
    spec:
      containers:
        - name: manager
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          env:
            - name: GOMAXPROCS
              value: "2"
            - name: RECONCILE_WORKERS
              value: "10" # Increase for high throughput
            - name: RECONCILE_TIMEOUT
              value: "300s"
```

#### Reconciliation Optimization

```yaml
# Add to controller configuration
reconciliation:
  # Batch processing settings
  batchSize: 50
  batchTimeout: "30s"

  # Rate limiting
  rateLimit:
    qps: 100
    burst: 200

  # Concurrent reconcilers
  maxConcurrentReconciles: 10

  # Requeue delays
  requeueDelay: "30s"
  requeueDelayOnError: "5s"
```

### Resource Optimization

#### Machine Lifecycle Management

```bash
# Automated cleanup of failed machines
#!/bin/bash
# cleanup-failed-machines.sh

echo "Cleaning up failed machines older than 1 hour..."

kubectl get machines --all-namespaces \
  --field-selector=status.phase=Failed \
  -o json | jq -r '.items[] | select(.metadata.creationTimestamp | fromdateiso8601 < (now - 3600)) | "\(.metadata.namespace) \(.metadata.name)"' | \
while read namespace name; do
  echo "Deleting failed machine: $namespace/$name"
  kubectl delete machine "$name" -n "$namespace"
done
```

#### Provider Load Balancing

```yaml
# Configure multiple providers with priorities
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: optimized-vitistack
spec:
  machineProviders:
    - name: primary-provider
      priority: 1
      enabled: true
      configuration:
        maxConcurrentProvisions: 10
    - name: secondary-provider
      priority: 2
      enabled: true
      configuration:
        maxConcurrentProvisions: 5
    - name: burst-provider
      priority: 3
      enabled: true
      configuration:
        enableOnDemand: true
        costOptimized: true
```

### Monitoring Performance Metrics

#### Key Performance Indicators

```bash
# Controller performance metrics
kubectl top pods -n vitistack-system

# Reconciliation metrics
curl -s http://controller-metrics:8080/metrics | grep vitistack_controller

# Resource usage trends
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.resourceUsage}{"\n"}{end}'
```

## Backup and Recovery

### Automated Backup Procedures

#### Vitistack Configuration Backup

```bash
#!/bin/bash
# backup-vitistack-config.sh

BACKUP_DIR="/backup/vitistack/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

echo "Backing up VitiStack configuration to $BACKUP_DIR"

# Backup all CRDs
kubectl get vitistacks -o yaml > "$BACKUP_DIR/vitistacks.yaml"
kubectl get machineproviders -o yaml > "$BACKUP_DIR/machineproviders.yaml"
kubectl get kubernetesproviders -o yaml > "$BACKUP_DIR/kubernetesproviders.yaml"
kubectl get machines --all-namespaces -o yaml > "$BACKUP_DIR/machines.yaml"

# Backup secrets
kubectl get secrets -l vitistack.io/component=provider-auth -o yaml > "$BACKUP_DIR/secrets.yaml"

# Backup RBAC
kubectl get clusterroles,clusterrolebindings -l vitistack.io/component=rbac -o yaml > "$BACKUP_DIR/rbac.yaml"

# Create manifest
cat > "$BACKUP_DIR/manifest.txt" << EOF
Backup created: $(date)
Kubernetes version: $(kubectl version --short)
VitiStack version: $(kubectl get deployment vitistack-controller -n vitistack-system -o jsonpath='{.spec.template.spec.containers[0].image}')
Vitistacks: $(kubectl get vitistacks --no-headers | wc -l)
Machine Providers: $(kubectl get machineproviders --no-headers | wc -l)
Kubernetes Providers: $(kubectl get kubernetesproviders --no-headers | wc -l)
Machines: $(kubectl get machines --all-namespaces --no-headers | wc -l)
EOF

echo "Backup completed: $BACKUP_DIR"
```

#### Disaster Recovery Procedures

```bash
#!/bin/bash
# restore-vitistack.sh

BACKUP_DIR=$1
if [ -z "$BACKUP_DIR" ]; then
    echo "Usage: $0 <backup-directory>"
    exit 1
fi

echo "Restoring VitiStack from $BACKUP_DIR"

# Verify backup integrity
if [ ! -f "$BACKUP_DIR/manifest.txt" ]; then
    echo "Invalid backup directory"
    exit 1
fi

# Restore in order
echo "Restoring secrets..."
kubectl apply -f "$BACKUP_DIR/secrets.yaml"

echo "Restoring RBAC..."
kubectl apply -f "$BACKUP_DIR/rbac.yaml"

echo "Restoring providers..."
kubectl apply -f "$BACKUP_DIR/machineproviders.yaml"
kubectl apply -f "$BACKUP_DIR/kubernetesproviders.yaml"

echo "Waiting for providers to be ready..."
kubectl wait --for=condition=Ready machineproviders --all --timeout=300s
kubectl wait --for=condition=Ready kubernetesproviders --all --timeout=300s

echo "Restoring vitistacks..."
kubectl apply -f "$BACKUP_DIR/vitistacks.yaml"

echo "Restoring machines..."
kubectl apply -f "$BACKUP_DIR/machines.yaml"

echo "Restoration completed"
```

### Cross-Region Backup Strategy

```yaml
# backup-policy.yaml
apiVersion: vitistack.io/v1alpha1
kind: Vitistack
metadata:
  name: primary-vitistack
spec:
  backup:
    enabled: true
    schedule: "0 2 * * *" # Daily at 2 AM
    destinations:
      - name: s3-primary
        type: s3
        configuration:
          bucket: vitistack-backup-primary
          region: us-east-1
          encryption: true
      - name: s3-secondary
        type: s3
        configuration:
          bucket: vitistack-backup-secondary
          region: us-west-2
          encryption: true
    retentionPolicy:
      daily: 7
      weekly: 4
      monthly: 12
    disasterRecovery:
      enabled: true
      targetVitistack: disaster-recovery-vitistack
      rpoMinutes: 60
      rtoMinutes: 240
```

## Security Operations

### Security Monitoring

#### Access Audit Script

```bash
#!/bin/bash
# security-audit.sh

echo "=== VitiStack Security Audit ==="

echo "RBAC Configuration:"
kubectl get clusterroles,roles | grep vitistack

echo -e "\nService Accounts:"
kubectl get serviceaccounts -A | grep vitistack

echo -e "\nSecret Usage:"
kubectl get secrets -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.type}{"\n"}{end}' | grep vitistack

echo -e "\nEncryption Status:"
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.security.encryption}{"\n"}{end}'

echo -e "\nCompliance Frameworks:"
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.security.complianceFrameworks}{"\n"}{end}'

echo -e "\nAudit Logging:"
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.security.auditLogging.enabled}{"\n"}{end}'
```

#### Security Hardening Checklist

```yaml
# security-baseline.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vitistack-security-baseline
data:
  security-checklist.yaml: |
    mandatory:
      - name: "Encryption at Rest"
        check: "spec.security.encryption.atRest == true"
      - name: "Encryption in Transit"
        check: "spec.security.encryption.inTransit == true"
      - name: "RBAC Enabled"
        check: "spec.security.accessControl.rbac == true"
      - name: "Audit Logging"
        check: "spec.security.auditLogging.enabled == true"

    recommended:
      - name: "MFA Required"
        check: "spec.security.accessControl.mfa == true"
      - name: "Compliance Framework"
        check: "spec.security.complianceFrameworks != null"
      - name: "Network Policies"
        check: "spec.networking.firewall.defaultPolicy == 'deny'"
```

### Incident Response Playbooks

#### Security Incident Response

```bash
#!/bin/bash
# security-incident-response.sh

INCIDENT_TYPE=$1
AFFECTED_RESOURCE=$2

case $INCIDENT_TYPE in
    "credential-compromise")
        echo "Responding to credential compromise for $AFFECTED_RESOURCE"

        # Rotate compromised credentials
        kubectl delete secret "$AFFECTED_RESOURCE-auth"

        # Disable affected provider
        kubectl patch machineprovider "$AFFECTED_RESOURCE" -p='{"spec":{"enabled":false}}'

        # Alert security team
        curl -X POST "$SLACK_WEBHOOK" -d "{\"text\":\"SECURITY ALERT: Credential compromise detected for $AFFECTED_RESOURCE\"}"
        ;;

    "unauthorized-access")
        echo "Responding to unauthorized access attempt"

        # Enable enhanced audit logging
        kubectl patch vitistacks --type='merge' -p='{"spec":{"security":{"auditLogging":{"retentionDays":90}}}}'

        # Review recent activities
        kubectl get events --sort-by=.metadata.creationTimestamp | grep -i "$AFFECTED_RESOURCE"
        ;;
esac
```

## Capacity Planning

### Resource Forecasting

#### Usage Trend Analysis

```bash
#!/bin/bash
# capacity-analysis.sh

echo "=== Capacity Analysis Report ==="

echo "Current Resource Usage:"
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.resourceUsage.cpuCoresUsed}/{.status.resourceUsage.cpuCoresTotal}{"\t"}{.status.resourceUsage.memoryGBUsed}/{.status.resourceUsage.memoryGBTotal}{"\n"}{end}' | column -t

echo -e "\nGrowth Trends (30-day):"
# This would typically integrate with your metrics system
curl -s "http://prometheus:9090/api/v1/query_range?query=vitistack_vitistack_cpu_used&start=$(date -d '30 days ago' +%s)&end=$(date +%s)&step=86400" | jq '.data.result'

echo -e "\nCapacity Recommendations:"
kubectl get vitistacks -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{(.status.resourceUsage.cpuCoresUsed / .status.resourceUsage.cpuCoresTotal * 100)}{"%\t"}{(.status.resourceUsage.memoryGBUsed / .status.resourceUsage.memoryGBTotal * 100)}{"%\n"}{end}' | awk '$2 > 80 || $3 > 80 {print "RECOMMEND EXPANSION: " $1 " (CPU: " $2 ", Memory: " $3 ")"}'
```

#### Scaling Recommendations

```yaml
# capacity-planning-policy.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: capacity-planning-rules
data:
  scaling-rules.yaml: |
    cpu_threshold: 80
    memory_threshold: 80
    storage_threshold: 85

    scaling_actions:
      - condition: "cpu_usage > cpu_threshold"
        action: "add_machine_provider"
        priority: "high"
      
      - condition: "memory_usage > memory_threshold"
        action: "increase_instance_sizes"
        priority: "medium"
      
      - condition: "storage_usage > storage_threshold"
        action: "add_storage_tier"
        priority: "medium"

    forecast_models:
      - type: "linear_growth"
        lookback_days: 30
        forecast_days: 90
      
      - type: "seasonal_pattern"
        lookback_days: 365
        forecast_days: 90
```

## Alerting and Notifications

### Alert Configuration

#### Critical Alerts

```yaml
# critical-alerts.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: vitistack-critical-alerts
spec:
  groups:
    - name: vitistack.critical
      rules:
        - alert: VitistackDown
          expr: vitistack_vitistack_ready == 0
          for: 1m
          labels:
            severity: critical
            team: platform
          annotations:
            summary: "Vitistack {{ $labels.vitistack }} is down"
            description: "Critical infrastructure failure in vitistack {{ $labels.vitistack }}"
            runbook_url: "https://wiki.company.com/vitistack/runbooks/vitistack-down"

        - alert: MassProvisioningFailure
          expr: rate(vitistack_machine_provisioning_failures_total[5m]) > 0.5
          for: 2m
          labels:
            severity: critical
            team: platform
          annotations:
            summary: "High rate of machine provisioning failures"
            description: "More than 50% of machine provisioning attempts are failing"

        - alert: ProviderAuthenticationFailure
          expr: vitistack_provider_auth_failures_total > 0
          for: 0m
          labels:
            severity: critical
            team: security
          annotations:
            summary: "Provider authentication failure detected"
            description: "Authentication failure for provider {{ $labels.provider }}"
```

#### Notification Channels

```yaml
# alertmanager-config.yaml
global:
  slack_api_url: "https://hooks.slack.com/services/..."

route:
  group_by: ["alertname", "severity"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: "default"
  routes:
    - match:
        severity: critical
        team: platform
      receiver: "platform-critical"
    - match:
        severity: critical
        team: security
      receiver: "security-critical"

receivers:
  - name: "default"
    slack_configs:
      - channel: "#vitistack-alerts"
        title: "VitiStack Alert"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"

  - name: "platform-critical"
    slack_configs:
      - channel: "#platform-critical"
        title: "CRITICAL: VitiStack Platform Alert"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
    pagerduty_configs:
      - service_key: "platform-service-key"

  - name: "security-critical"
    slack_configs:
      - channel: "#security-incidents"
        title: "SECURITY ALERT: VitiStack"
        text: "{{ range .Alerts }}{{ .Annotations.description }}{{ end }}"
    email_configs:
      - to: "security-team@company.com"
        subject: "SECURITY ALERT: VitiStack Authentication Failure"
```

## Maintenance Procedures

### Routine Maintenance

#### Weekly Maintenance Checklist

```bash
#!/bin/bash
# weekly-maintenance.sh

echo "=== VitiStack Weekly Maintenance ==="

# 1. Health Check
echo "Running health checks..."
./vitistack-healthcheck.sh

# 2. Resource Cleanup
echo "Cleaning up resources..."
kubectl delete machines --all-namespaces --field-selector=status.phase=Failed

# 3. Log Rotation
echo "Rotating logs..."
kubectl logs -n vitistack-system deployment/vitistack-controller --previous > /var/log/vitistack/controller-$(date +%Y%m%d).log

# 4. Backup Verification
echo "Verifying backups..."
aws s3 ls s3://vitistack-backup-primary/$(date +%Y/%m/%d)/ || echo "WARNING: Daily backup missing"

# 5. Capacity Review
echo "Reviewing capacity..."
./capacity-analysis.sh > /var/log/vitistack/capacity-$(date +%Y%m%d).log

# 6. Security Audit
echo "Running security audit..."
./security-audit.sh > /var/log/vitistack/security-$(date +%Y%m%d).log

# 7. Update Check
echo "Checking for updates..."
kubectl get deployment vitistack-controller -n vitistack-system -o jsonpath='{.spec.template.spec.containers[0].image}'

echo "Weekly maintenance completed"
```

#### Controller Updates

```bash
#!/bin/bash
# update-controller.sh

NEW_VERSION=$1
if [ -z "$NEW_VERSION" ]; then
    echo "Usage: $0 <new-version>"
    exit 1
fi

echo "Updating VitiStack controller to version $NEW_VERSION"

# 1. Backup current configuration
./backup-vitistack-config.sh

# 2. Update controller image
kubectl set image deployment/vitistack-controller manager=vitistack/controller:$NEW_VERSION -n vitistack-system

# 3. Wait for rollout
kubectl rollout status deployment/vitistack-controller -n vitistack-system --timeout=300s

# 4. Verify health
sleep 30
./vitistack-healthcheck.sh

# 5. Test basic functionality
kubectl get vitistacks
kubectl get machineproviders

echo "Controller update completed successfully"
```

### Migration Procedures

#### Cluster Migration

```bash
#!/bin/bash
# migrate-cluster.sh

SOURCE_CLUSTER=$1
TARGET_CLUSTER=$2

if [ -z "$SOURCE_CLUSTER" ] || [ -z "$TARGET_CLUSTER" ]; then
    echo "Usage: $0 <source-cluster> <target-cluster>"
    exit 1
fi

echo "Migrating VitiStack from $SOURCE_CLUSTER to $TARGET_CLUSTER"

# 1. Backup from source
kubectl --context=$SOURCE_CLUSTER get vitistacks,machineproviders,kubernetesproviders -o yaml > migration-backup.yaml

# 2. Switch to target cluster
kubectl config use-context $TARGET_CLUSTER

# 3. Verify target cluster readiness
kubectl get nodes
kubectl get namespaces

# 4. Apply CRDs if not present
kubectl apply -f crds/

# 5. Deploy controller
kubectl apply -f config/

# 6. Wait for controller
kubectl wait --for=condition=Available deployment/vitistack-controller -n vitistack-system --timeout=300s

# 7. Apply migrated resources
kubectl apply -f migration-backup.yaml

# 8. Verify migration
kubectl get vitistacks,machineproviders,kubernetesproviders

echo "Migration completed"
```

## Health Check Procedures

### Comprehensive Health Checks

#### System-Wide Health Check

```bash
#!/bin/bash
# comprehensive-health-check.sh

HEALTH_SCORE=0
TOTAL_CHECKS=0

check_and_score() {
    local check_name="$1"
    local check_command="$2"
    local weight="${3:-1}"

    echo -n "Checking $check_name... "
    TOTAL_CHECKS=$((TOTAL_CHECKS + weight))

    if eval "$check_command" &>/dev/null; then
        echo "✅ PASS"
        HEALTH_SCORE=$((HEALTH_SCORE + weight))
        return 0
    else
        echo "❌ FAIL"
        return 1
    fi
}

echo "=== VitiStack Comprehensive Health Check ==="

# Controller Health
check_and_score "Controller Pod Running" "kubectl get pods -n vitistack-system -l app=vitistack-controller --field-selector=status.phase=Running" 5

# CRD Availability
check_and_score "Vitistack CRD" "kubectl get crd vitistacks.vitistack.io" 2
check_and_score "Machine CRD" "kubectl get crd machines.vitistack.io" 2
check_and_score "MachineProvider CRD" "kubectl get crd machineproviders.vitistack.io" 2
check_and_score "KubernetesProvider CRD" "kubectl get crd kubernetesproviders.vitistack.io" 2

# Resource Health
check_and_score "Vitistacks Ready" "kubectl get vitistacks -o jsonpath='{.items[*].status.conditions[?(@.type==\"Ready\")].status}' | grep -q True" 5
check_and_score "Providers Authenticated" "kubectl get machineproviders -o jsonpath='{.items[*].status.conditions[?(@.type==\"AuthenticationValid\")].status}' | grep -qv False" 3

# Metrics and Monitoring
check_and_score "Metrics Endpoint" "curl -s http://controller-metrics:8080/metrics | grep -q vitistack" 2
check_and_score "Prometheus Targets" "curl -s http://prometheus:9090/api/v1/targets | jq -r '.data.activeTargets[] | select(.labels.job == \"vitistack-controller\") | .health' | grep -q up" 2

# Calculate health percentage
HEALTH_PERCENTAGE=$((HEALTH_SCORE * 100 / TOTAL_CHECKS))

echo "=== Health Check Summary ==="
echo "Score: $HEALTH_SCORE/$TOTAL_CHECKS ($HEALTH_PERCENTAGE%)"

if [ $HEALTH_PERCENTAGE -ge 90 ]; then
    echo "Status: 🟢 HEALTHY"
    exit 0
elif [ $HEALTH_PERCENTAGE -ge 70 ]; then
    echo "Status: 🟡 DEGRADED"
    exit 1
else
    echo "Status: 🔴 UNHEALTHY"
    exit 2
fi
```

This operational guide provides comprehensive procedures for managing VitiStack in production environments. It covers monitoring, troubleshooting, performance optimization, backup and recovery, security operations, capacity planning, incident response, maintenance procedures, and health checks. The guide includes practical scripts, configuration examples, and step-by-step procedures that operations teams can use to maintain a healthy and efficient VitiStack deployment.

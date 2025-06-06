# VitiStack Performance Optimization Guide

## Overview

This guide provides comprehensive strategies for optimizing the performance of VitiStack CRDs in production environments. It covers controller optimization, resource management, scaling strategies, monitoring, and best practices for achieving optimal performance across multi-cloud infrastructure deployments.

## Table of Contents

- [Performance Architecture](#performance-architecture)
- [Controller Optimization](#controller-optimization)
- [Resource Management](#resource-management)
- [Scaling Strategies](#scaling-strategies)
- [Caching and Buffering](#caching-and-buffering)
- [Network Optimization](#network-optimization)
- [Storage Performance](#storage-performance)
- [Monitoring and Metrics](#monitoring-and-metrics)
- [Troubleshooting Performance Issues](#troubleshooting-performance-issues)
- [Best Practices](#best-practices)

## Performance Architecture

### High-Performance Design Principles

#### 1. Asynchronous Processing
```go
// High-performance controller architecture
type OptimizedController struct {
    Client     client.Client
    WorkQueue  workqueue.RateLimitingInterface
    Workers    int
    BatchSize  int
    Cache      cache.Cache
}

func (c *OptimizedController) processWorkItem() bool {
    obj, shutdown := c.WorkQueue.Get()
    if shutdown {
        return false
    }
    defer c.WorkQueue.Done(obj)

    key, ok := obj.(string)
    if !ok {
        c.WorkQueue.Forget(obj)
        return true
    }

    // Process with timeout and retries
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := c.reconcileWithRetry(ctx, key); err != nil {
        if c.WorkQueue.NumRequeues(obj) < 5 {
            c.WorkQueue.AddRateLimited(obj)
            return true
        }
        c.WorkQueue.Forget(obj)
    }

    c.WorkQueue.Forget(obj)
    return true
}
```

#### 2. Batch Processing Architecture
```yaml
# controller-performance-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vitistack-performance-config
  namespace: vitistack-system
data:
  performance.yaml: |
    controller:
      workers: 20
      batchSize: 50
      batchTimeout: "30s"
      maxConcurrentReconciles: 15
      
    caching:
      enabled: true
      ttl: "5m"
      maxSize: 10000
      
    rateLimit:
      qps: 200
      burst: 400
      
    reconciliation:
      requeueDelay: "30s"
      requeueDelayOnError: "5s"
      timeout: "300s"
      
    resourceOptimization:
      cpu:
        requests: "500m"
        limits: "2000m"
      memory:
        requests: "1Gi"
        limits: "4Gi"
      
    monitoring:
      metricsInterval: "15s"
      enableProfiling: true
```

## Controller Optimization

### Multi-Worker Architecture

#### Optimized Controller Deployment
```yaml
# optimized-controller-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vitistack-controller
  namespace: vitistack-system
spec:
  replicas: 3  # For high availability
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 1
  template:
    metadata:
      labels:
        app: vitistack-controller
        version: optimized
    spec:
      serviceAccountName: vitistack-controller
      containers:
      - name: manager
        image: vitistack/controller:latest
        imagePullPolicy: Always
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
          limits:
            cpu: 2000m
            memory: 4Gi
        env:
        - name: GOMAXPROCS
          value: "4"
        - name: RECONCILE_WORKERS
          value: "20"
        - name: BATCH_SIZE
          value: "50"
        - name: CACHE_SIZE
          value: "10000"
        - name: ENABLE_PPROF
          value: "true"
        - name: METRICS_BIND_ADDR
          value: ":8080"
        - name: HEALTH_PROBE_BIND_ADDR
          value: ":8081"
        - name: LEADER_ELECT
          value: "true"
        ports:
        - containerPort: 8080
          name: metrics
          protocol: TCP
        - containerPort: 8081
          name: health
          protocol: TCP
        - containerPort: 6060
          name: pprof
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
        volumeMounts:
        - name: performance-config
          mountPath: /etc/config
      volumes:
      - name: performance-config
        configMap:
          name: vitistack-performance-config
      nodeSelector:
        node-type: controller
      tolerations:
      - key: node-type
        operator: Equal
        value: controller
        effect: NoSchedule
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: vitistack-controller
              topologyKey: kubernetes.io/hostname
```

### Controller Performance Tuning

#### Optimized Reconciliation Logic
```go
// pkg/controller/optimized_reconciler.go
package controller

import (
    "context"
    "sync"
    "time"

    "k8s.io/client-go/util/workqueue"
    ctrl "sigs.k8s.io/controller-runtime"
    "sigs.k8s.io/controller-runtime/pkg/client"
)

type HighPerformanceReconciler struct {
    Client          client.Client
    BatchProcessor  *BatchProcessor
    Cache          *ResourceCache
    MetricsRecorder *MetricsRecorder
}

type BatchProcessor struct {
    batchSize    int
    batchTimeout time.Duration
    items        []reconcileItem
    mutex        sync.Mutex
    timer        *time.Timer
}

type reconcileItem struct {
    key       string
    timestamp time.Time
    retries   int
}

func (r *HighPerformanceReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
    start := time.Now()
    defer func() {
        r.MetricsRecorder.RecordReconcileTime(time.Since(start))
    }()

    // Check cache first
    if cached, found := r.Cache.Get(req.String()); found {
        if time.Since(cached.LastUpdate) < 5*time.Minute {
            return ctrl.Result{}, nil
        }
    }

    // Add to batch processor
    r.BatchProcessor.Add(reconcileItem{
        key:       req.String(),
        timestamp: time.Now(),
    })

    return ctrl.Result{}, nil
}

func (bp *BatchProcessor) Add(item reconcileItem) {
    bp.mutex.Lock()
    defer bp.mutex.Unlock()

    bp.items = append(bp.items, item)

    if len(bp.items) >= bp.batchSize {
        bp.processBatch()
        return
    }

    if bp.timer == nil {
        bp.timer = time.AfterFunc(bp.batchTimeout, bp.processBatch)
    }
}

func (bp *BatchProcessor) processBatch() {
    bp.mutex.Lock()
    items := make([]reconcileItem, len(bp.items))
    copy(items, bp.items)
    bp.items = bp.items[:0]
    if bp.timer != nil {
        bp.timer.Stop()
        bp.timer = nil
    }
    bp.mutex.Unlock()

    // Process items in parallel
    var wg sync.WaitGroup
    semaphore := make(chan struct{}, 10) // Limit concurrency

    for _, item := range items {
        wg.Add(1)
        go func(i reconcileItem) {
            defer wg.Done()
            semaphore <- struct{}{}
            defer func() { <-semaphore }()

            bp.processItem(i)
        }(item)
    }

    wg.Wait()
}
```

#### Resource Cache Implementation
```go
// pkg/cache/resource_cache.go
package cache

import (
    "sync"
    "time"
)

type ResourceCache struct {
    items map[string]*CacheItem
    mutex sync.RWMutex
    ttl   time.Duration
}

type CacheItem struct {
    Data       interface{}
    LastUpdate time.Time
    AccessTime time.Time
    HitCount   int64
}

func NewResourceCache(ttl time.Duration) *ResourceCache {
    cache := &ResourceCache{
        items: make(map[string]*CacheItem),
        ttl:   ttl,
    }
    
    // Start cleanup goroutine
    go cache.cleanup()
    
    return cache
}

func (c *ResourceCache) Get(key string) (*CacheItem, bool) {
    c.mutex.RLock()
    defer c.mutex.RUnlock()

    item, exists := c.items[key]
    if !exists {
        return nil, false
    }

    if time.Since(item.LastUpdate) > c.ttl {
        go c.Delete(key) // Async cleanup
        return nil, false
    }

    item.AccessTime = time.Now()
    item.HitCount++
    return item, true
}

func (c *ResourceCache) Set(key string, data interface{}) {
    c.mutex.Lock()
    defer c.mutex.Unlock()

    c.items[key] = &CacheItem{
        Data:       data,
        LastUpdate: time.Now(),
        AccessTime: time.Now(),
        HitCount:   0,
    }
}

func (c *ResourceCache) Delete(key string) {
    c.mutex.Lock()
    defer c.mutex.Unlock()
    delete(c.items, key)
}

func (c *ResourceCache) cleanup() {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()

    for range ticker.C {
        c.mutex.Lock()
        now := time.Now()
        for key, item := range c.items {
            if now.Sub(item.LastUpdate) > c.ttl || 
               now.Sub(item.AccessTime) > 2*c.ttl {
                delete(c.items, key)
            }
        }
        c.mutex.Unlock()
    }
}

func (c *ResourceCache) Stats() CacheStats {
    c.mutex.RLock()
    defer c.mutex.RUnlock()

    var totalHits int64
    for _, item := range c.items {
        totalHits += item.HitCount
    }

    return CacheStats{
        Size:      len(c.items),
        TotalHits: totalHits,
    }
}

type CacheStats struct {
    Size      int
    TotalHits int64
}
```

## Resource Management

### Memory Optimization

#### Memory-Efficient Controller Configuration
```go
// pkg/controller/memory_optimized.go
package controller

import (
    "runtime"
    "runtime/debug"
    "time"
)

type MemoryOptimizedController struct {
    gcThreshold int64
    lastGC      time.Time
    memStats    runtime.MemStats
}

func (c *MemoryOptimizedController) optimizeMemory() {
    // Get current memory stats
    runtime.ReadMemStats(&c.memStats)

    // Force GC if memory usage is high
    if c.memStats.Alloc > uint64(c.gcThreshold) {
        if time.Since(c.lastGC) > 30*time.Second {
            runtime.GC()
            debug.FreeOSMemory()
            c.lastGC = time.Now()
        }
    }

    // Adjust GOGC based on memory pressure
    if c.memStats.Alloc > uint64(c.gcThreshold*2) {
        debug.SetGCPercent(50) // More aggressive GC
    } else {
        debug.SetGCPercent(100) // Default GC
    }
}

func (c *MemoryOptimizedController) startMemoryMonitoring() {
    ticker := time.NewTicker(30 * time.Second)
    go func() {
        for range ticker.C {
            c.optimizeMemory()
        }
    }()
}
```

#### Resource Pool Management
```go
// pkg/pool/resource_pool.go
package pool

import (
    "sync"
)

type ResourcePool struct {
    pool sync.Pool
    maxSize int
    current int
    mutex   sync.Mutex
}

func NewResourcePool(createFunc func() interface{}, maxSize int) *ResourcePool {
    return &ResourcePool{
        pool: sync.Pool{
            New: createFunc,
        },
        maxSize: maxSize,
    }
}

func (p *ResourcePool) Get() interface{} {
    return p.pool.Get()
}

func (p *ResourcePool) Put(item interface{}) {
    p.mutex.Lock()
    defer p.mutex.Unlock()

    if p.current < p.maxSize {
        p.pool.Put(item)
        p.current++
    }
    // If pool is full, let GC handle the item
}

// Example usage for HTTP clients
var httpClientPool = NewResourcePool(
    func() interface{} {
        return &http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:        100,
                MaxIdleConnsPerHost: 10,
                IdleConnTimeout:     90 * time.Second,
            },
        }
    },
    50,
)
```

### CPU Optimization

#### CPU-Efficient Processing
```go
// pkg/processor/cpu_optimized.go
package processor

import (
    "context"
    "runtime"
    "sync"
)

type CPUOptimizedProcessor struct {
    workerCount int
    workQueue   chan WorkItem
    wg          sync.WaitGroup
}

type WorkItem struct {
    ID   string
    Data interface{}
    Ctx  context.Context
}

func NewCPUOptimizedProcessor() *CPUOptimizedProcessor {
    workerCount := runtime.GOMAXPROCS(0) * 2 // 2x CPU cores
    
    processor := &CPUOptimizedProcessor{
        workerCount: workerCount,
        workQueue:   make(chan WorkItem, workerCount*10),
    }
    
    processor.startWorkers()
    return processor
}

func (p *CPUOptimizedProcessor) startWorkers() {
    for i := 0; i < p.workerCount; i++ {
        go p.worker(i)
    }
}

func (p *CPUOptimizedProcessor) worker(id int) {
    for item := range p.workQueue {
        // Process item with CPU affinity optimization
        p.processItem(item)
    }
}

func (p *CPUOptimizedProcessor) Submit(item WorkItem) {
    select {
    case p.workQueue <- item:
        // Item queued successfully
    default:
        // Queue full, handle backpressure
        go func() {
            p.workQueue <- item
        }()
    }
}

func (p *CPUOptimizedProcessor) processItem(item WorkItem) {
    defer func() {
        if r := recover(); r != nil {
            // Handle panic gracefully
        }
    }()
    
    // CPU-intensive processing logic
    switch data := item.Data.(type) {
    case *DatacenterSpec:
        p.processDatacenter(item.Ctx, data)
    case *MachineSpec:
        p.processMachine(item.Ctx, data)
    }
}
```

## Scaling Strategies

### Horizontal Pod Autoscaling

#### HPA Configuration for Controller
```yaml
# controller-hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: vitistack-controller-hpa
  namespace: vitistack-system
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vitistack-controller
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: reconcile_queue_depth
        selector:
          matchLabels:
            app: vitistack-controller
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
      - type: Pods
        value: 4
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### Vertical Pod Autoscaling

#### VPA Configuration
```yaml
# controller-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: vitistack-controller-vpa
  namespace: vitistack-system
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: vitistack-controller
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: manager
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 4000m
        memory: 8Gi
      controlledResources: ["cpu", "memory"]
      controlledValues: RequestsAndLimits
```

### Custom Metrics Scaling

#### Custom Metrics for Scaling
```go
// pkg/metrics/custom_metrics.go
package metrics

import (
    "context"
    
    "k8s.io/metrics/pkg/apis/custom_metrics/v1beta1"
    "sigs.k8s.io/custom-metrics-apiserver/pkg/provider"
)

type VitiStackMetricsProvider struct {
    client client.Client
}

func (p *VitiStackMetricsProvider) GetMetricByName(
    ctx context.Context,
    name types.NamespacedName,
    info provider.CustomMetricInfo,
    metricSelector labels.Selector,
) (*custom_metrics.MetricValue, error) {
    
    switch info.Metric {
    case "reconcile_queue_depth":
        return p.getReconcileQueueDepth(ctx, name)
    case "provider_utilization":
        return p.getProviderUtilization(ctx, name)
    case "machine_provisioning_rate":
        return p.getMachineProvisioningRate(ctx, name)
    default:
        return nil, provider.NewMetricNotFoundError(info.GroupResource, info.Metric)
    }
}

func (p *VitiStackMetricsProvider) getReconcileQueueDepth(ctx context.Context, name types.NamespacedName) (*custom_metrics.MetricValue, error) {
    // Get current queue depth from controller metrics
    queueDepth := getCurrentQueueDepth()
    
    return &custom_metrics.MetricValue{
        DescribedObject: custom_metrics.ObjectReference{
            Kind:      "Pod",
            Name:      name.Name,
            Namespace: name.Namespace,
        },
        MetricName: "reconcile_queue_depth",
        Timestamp:  metav1.Now(),
        Value:      *resource.NewQuantity(int64(queueDepth), resource.DecimalSI),
    }, nil
}
```

## Caching and Buffering

### Multi-Level Caching Strategy

#### L1 Cache (In-Memory)
```go
// pkg/cache/l1_cache.go
package cache

import (
    "container/list"
    "sync"
    "time"
)

type L1Cache struct {
    capacity int
    items    map[string]*list.Element
    lru      *list.List
    mutex    sync.RWMutex
    ttl      time.Duration
}

type cacheEntry struct {
    key        string
    value      interface{}
    expiration time.Time
}

func NewL1Cache(capacity int, ttl time.Duration) *L1Cache {
    cache := &L1Cache{
        capacity: capacity,
        items:    make(map[string]*list.Element),
        lru:      list.New(),
        ttl:      ttl,
    }
    
    go cache.evictionTicker()
    return cache
}

func (c *L1Cache) Get(key string) (interface{}, bool) {
    c.mutex.RLock()
    defer c.mutex.RUnlock()

    if elem, exists := c.items[key]; exists {
        entry := elem.Value.(*cacheEntry)
        if time.Now().Before(entry.expiration) {
            c.lru.MoveToFront(elem)
            return entry.value, true
        }
        // Expired, will be cleaned up by eviction ticker
    }
    return nil, false
}

func (c *L1Cache) Set(key string, value interface{}) {
    c.mutex.Lock()
    defer c.mutex.Unlock()

    if elem, exists := c.items[key]; exists {
        c.lru.MoveToFront(elem)
        entry := elem.Value.(*cacheEntry)
        entry.value = value
        entry.expiration = time.Now().Add(c.ttl)
        return
    }

    if c.lru.Len() >= c.capacity {
        c.evictLRU()
    }

    entry := &cacheEntry{
        key:        key,
        value:      value,
        expiration: time.Now().Add(c.ttl),
    }
    
    elem := c.lru.PushFront(entry)
    c.items[key] = elem
}

func (c *L1Cache) evictLRU() {
    elem := c.lru.Back()
    if elem != nil {
        c.lru.Remove(elem)
        entry := elem.Value.(*cacheEntry)
        delete(c.items, entry.key)
    }
}

func (c *L1Cache) evictionTicker() {
    ticker := time.NewTicker(time.Minute)
    defer ticker.Stop()

    for range ticker.C {
        c.mutex.Lock()
        now := time.Now()
        
        for key, elem := range c.items {
            entry := elem.Value.(*cacheEntry)
            if now.After(entry.expiration) {
                c.lru.Remove(elem)
                delete(c.items, key)
            }
        }
        c.mutex.Unlock()
    }
}
```

#### L2 Cache (Redis)
```go
// pkg/cache/l2_cache.go
package cache

import (
    "context"
    "encoding/json"
    "time"

    "github.com/go-redis/redis/v8"
)

type L2Cache struct {
    client *redis.Client
    prefix string
    ttl    time.Duration
}

func NewL2Cache(redisAddr, password string, db int, prefix string, ttl time.Duration) *L2Cache {
    rdb := redis.NewClient(&redis.Options{
        Addr:     redisAddr,
        Password: password,
        DB:       db,
        PoolSize: 20,
    })

    return &L2Cache{
        client: rdb,
        prefix: prefix,
        ttl:    ttl,
    }
}

func (c *L2Cache) Get(ctx context.Context, key string) (interface{}, error) {
    fullKey := c.prefix + ":" + key
    val, err := c.client.Get(ctx, fullKey).Result()
    if err != nil {
        if err == redis.Nil {
            return nil, ErrCacheMiss
        }
        return nil, err
    }

    var result interface{}
    err = json.Unmarshal([]byte(val), &result)
    return result, err
}

func (c *L2Cache) Set(ctx context.Context, key string, value interface{}) error {
    fullKey := c.prefix + ":" + key
    
    data, err := json.Marshal(value)
    if err != nil {
        return err
    }

    return c.client.Set(ctx, fullKey, data, c.ttl).Err()
}

func (c *L2Cache) Delete(ctx context.Context, key string) error {
    fullKey := c.prefix + ":" + key
    return c.client.Del(ctx, fullKey).Err()
}
```

### Write-Through Caching Pattern
```go
// pkg/cache/write_through.go
package cache

import (
    "context"
    "sync"
)

type WriteThroughCache struct {
    l1Cache *L1Cache
    l2Cache *L2Cache
    source  DataSource
    mutex   sync.RWMutex
}

type DataSource interface {
    Get(ctx context.Context, key string) (interface{}, error)
    Set(ctx context.Context, key string, value interface{}) error
    Delete(ctx context.Context, key string) error
}

func NewWriteThroughCache(l1 *L1Cache, l2 *L2Cache, source DataSource) *WriteThroughCache {
    return &WriteThroughCache{
        l1Cache: l1,
        l2Cache: l2,
        source:  source,
    }
}

func (c *WriteThroughCache) Get(ctx context.Context, key string) (interface{}, error) {
    // Try L1 cache first
    if value, found := c.l1Cache.Get(key); found {
        return value, nil
    }

    // Try L2 cache
    if value, err := c.l2Cache.Get(ctx, key); err == nil {
        c.l1Cache.Set(key, value)
        return value, nil
    }

    // Fallback to source
    value, err := c.source.Get(ctx, key)
    if err != nil {
        return nil, err
    }

    // Update both cache levels
    c.l1Cache.Set(key, value)
    c.l2Cache.Set(ctx, key, value)

    return value, nil
}

func (c *WriteThroughCache) Set(ctx context.Context, key string, value interface{}) error {
    // Write to source first
    if err := c.source.Set(ctx, key, value); err != nil {
        return err
    }

    // Update both cache levels
    c.l1Cache.Set(key, value)
    c.l2Cache.Set(ctx, key, value)

    return nil
}
```

## Network Optimization

### Connection Pooling and Reuse

#### Optimized HTTP Client Configuration
```go
// pkg/client/optimized_client.go
package client

import (
    "crypto/tls"
    "net"
    "net/http"
    "time"
)

func NewOptimizedHTTPClient() *http.Client {
    transport := &http.Transport{
        // Connection pooling
        MaxIdleConns:        100,
        MaxIdleConnsPerHost: 20,
        MaxConnsPerHost:     50,
        IdleConnTimeout:     90 * time.Second,
        
        // Connection timing
        DialContext: (&net.Dialer{
            Timeout:   10 * time.Second,
            KeepAlive: 30 * time.Second,
        }).DialContext,
        
        // TLS optimization
        TLSHandshakeTimeout: 10 * time.Second,
        TLSClientConfig: &tls.Config{
            InsecureSkipVerify: false,
            MinVersion:         tls.VersionTLS12,
        },
        
        // HTTP/2 optimization
        ForceAttemptHTTP2:     true,
        MaxResponseHeaderBytes: 4096,
        
        // Compression
        DisableCompression: false,
    }

    return &http.Client{
        Transport: transport,
        Timeout:   30 * time.Second,
    }
}
```

#### Cloud Provider Client Optimization
```go
// pkg/provider/optimized_aws_client.go
package provider

import (
    "context"
    "time"

    "github.com/aws/aws-sdk-go-v2/aws"
    "github.com/aws/aws-sdk-go-v2/config"
    "github.com/aws/aws-sdk-go-v2/service/ec2"
)

type OptimizedAWSClient struct {
    ec2Client *ec2.Client
    config    aws.Config
}

func NewOptimizedAWSClient(ctx context.Context, region string) (*OptimizedAWSClient, error) {
    cfg, err := config.LoadDefaultConfig(ctx,
        config.WithRegion(region),
        config.WithClientLogMode(aws.LogRetries|aws.LogRequest),
        config.WithRetryMaxAttempts(3),
        config.WithHTTPClient(&http.Client{
            Timeout: 30 * time.Second,
            Transport: &http.Transport{
                MaxIdleConns:        10,
                MaxIdleConnsPerHost: 5,
                IdleConnTimeout:     60 * time.Second,
            },
        }),
    )
    if err != nil {
        return nil, err
    }

    return &OptimizedAWSClient{
        ec2Client: ec2.NewFromConfig(cfg),
        config:    cfg,
    }, nil
}

func (c *OptimizedAWSClient) CreateInstancesBatch(ctx context.Context, requests []InstanceRequest) ([]InstanceResult, error) {
    // Batch multiple requests together
    batchSize := 10
    var results []InstanceResult
    
    for i := 0; i < len(requests); i += batchSize {
        end := i + batchSize
        if end > len(requests) {
            end = len(requests)
        }
        
        batch := requests[i:end]
        batchResults, err := c.processBatch(ctx, batch)
        if err != nil {
            return nil, err
        }
        
        results = append(results, batchResults...)
    }
    
    return results, nil
}
```

### Request Batching and Multiplexing

#### Batch Request Processor
```go
// pkg/batch/request_processor.go
package batch

import (
    "context"
    "sync"
    "time"
)

type BatchProcessor struct {
    batchSize    int
    flushTimeout time.Duration
    processor    func([]Request) error
    
    requests []Request
    mutex    sync.Mutex
    timer    *time.Timer
}

type Request struct {
    ID       string
    Data     interface{}
    Response chan Response
}

type Response struct {
    Result interface{}
    Error  error
}

func NewBatchProcessor(batchSize int, flushTimeout time.Duration, processor func([]Request) error) *BatchProcessor {
    return &BatchProcessor{
        batchSize:    batchSize,
        flushTimeout: flushTimeout,
        processor:    processor,
        requests:     make([]Request, 0, batchSize),
    }
}

func (bp *BatchProcessor) Submit(req Request) {
    bp.mutex.Lock()
    defer bp.mutex.Unlock()

    bp.requests = append(bp.requests, req)

    if len(bp.requests) >= bp.batchSize {
        bp.flush()
        return
    }

    if bp.timer == nil {
        bp.timer = time.AfterFunc(bp.flushTimeout, bp.flush)
    }
}

func (bp *BatchProcessor) flush() {
    bp.mutex.Lock()
    requests := make([]Request, len(bp.requests))
    copy(requests, bp.requests)
    bp.requests = bp.requests[:0]
    
    if bp.timer != nil {
        bp.timer.Stop()
        bp.timer = nil
    }
    bp.mutex.Unlock()

    if len(requests) == 0 {
        return
    }

    go func() {
        err := bp.processor(requests)
        for _, req := range requests {
            select {
            case req.Response <- Response{Error: err}:
            default:
                // Response channel might be closed
            }
        }
    }()
}
```

## Storage Performance

### Efficient Data Serialization

#### Optimized JSON Marshaling
```go
// pkg/serialization/optimized_json.go
package serialization

import (
    "encoding/json"
    "io"
    "sync"

    "github.com/json-iterator/go"
)

var (
    jsonIterator = jsoniter.ConfigCompatibleWithStandardLibrary
    bufferPool   = sync.Pool{
        New: func() interface{} {
            return make([]byte, 0, 1024)
        },
    }
)

type OptimizedSerializer struct {
    usePool bool
}

func NewOptimizedSerializer() *OptimizedSerializer {
    return &OptimizedSerializer{usePool: true}
}

func (s *OptimizedSerializer) Marshal(v interface{}) ([]byte, error) {
    if s.usePool {
        return jsonIterator.Marshal(v)
    }
    return json.Marshal(v)
}

func (s *OptimizedSerializer) MarshalToWriter(w io.Writer, v interface{}) error {
    encoder := jsonIterator.NewEncoder(w)
    return encoder.Encode(v)
}

func (s *OptimizedSerializer) Unmarshal(data []byte, v interface{}) error {
    return jsonIterator.Unmarshal(data, v)
}

func (s *OptimizedSerializer) UnmarshalFromReader(r io.Reader, v interface{}) error {
    decoder := jsonIterator.NewDecoder(r)
    return decoder.Decode(v)
}
```

### Database Connection Optimization

#### Optimized Database Pool
```go
// pkg/storage/db_pool.go
package storage

import (
    "context"
    "database/sql"
    "time"

    _ "github.com/lib/pq"
)

type OptimizedDBPool struct {
    db *sql.DB
}

func NewOptimizedDBPool(databaseURL string) (*OptimizedDBPool, error) {
    db, err := sql.Open("postgres", databaseURL)
    if err != nil {
        return nil, err
    }

    // Connection pool settings
    db.SetMaxOpenConns(50)
    db.SetMaxIdleConns(25)
    db.SetConnMaxLifetime(5 * time.Minute)
    db.SetConnMaxIdleTime(2 * time.Minute)

    // Verify connection
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel()
    
    if err := db.PingContext(ctx); err != nil {
        return nil, err
    }

    return &OptimizedDBPool{db: db}, nil
}

func (p *OptimizedDBPool) QueryWithCache(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    // Implement query result caching
    return p.db.QueryContext(ctx, query, args...)
}

func (p *OptimizedDBPool) PrepareStatement(query string) (*sql.Stmt, error) {
    return p.db.Prepare(query)
}
```

## Monitoring and Metrics

### Performance Metrics Collection

#### Custom Performance Metrics
```go
// pkg/metrics/performance_metrics.go
package metrics

import (
    "context"
    "time"

    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    reconcileTime = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "vitistack_reconcile_duration_seconds",
            Help: "Time taken to reconcile resources",
            Buckets: prometheus.ExponentialBuckets(0.001, 2, 15),
        },
        []string{"resource_type", "namespace"},
    )

    queueDepth = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "vitistack_queue_depth",
            Help: "Current depth of work queue",
        },
        []string{"controller", "queue_type"},
    )

    cacheHitRate = promauto.NewCounterVec(
        prometheus.CounterOpts{
            Name: "vitistack_cache_hits_total",
            Help: "Total number of cache hits",
        },
        []string{"cache_level", "cache_type"},
    )

    apiCallDuration = promauto.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "vitistack_api_call_duration_seconds",
            Help: "Time taken for external API calls",
            Buckets: prometheus.ExponentialBuckets(0.01, 2, 15),
        },
        []string{"provider", "operation"},
    )

    resourceUtilization = promauto.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "vitistack_resource_utilization_percent",
            Help: "Resource utilization percentage",
        },
        []string{"resource_type", "datacenter"},
    )
)

type MetricsRecorder struct {
    startTimes map[string]time.Time
}

func NewMetricsRecorder() *MetricsRecorder {
    return &MetricsRecorder{
        startTimes: make(map[string]time.Time),
    }
}

func (m *MetricsRecorder) RecordReconcileTime(duration time.Duration) {
    reconcileTime.WithLabelValues("datacenter", "default").Observe(duration.Seconds())
}

func (m *MetricsRecorder) RecordQueueDepth(controller string, queueType string, depth int) {
    queueDepth.WithLabelValues(controller, queueType).Set(float64(depth))
}

func (m *MetricsRecorder) RecordCacheHit(level string, cacheType string) {
    cacheHitRate.WithLabelValues(level, cacheType).Inc()
}

func (m *MetricsRecorder) StartAPICall(provider string, operation string) string {
    key := provider + ":" + operation
    m.startTimes[key] = time.Now()
    return key
}

func (m *MetricsRecorder) EndAPICall(key string, provider string, operation string) {
    if startTime, exists := m.startTimes[key]; exists {
        duration := time.Since(startTime)
        apiCallDuration.WithLabelValues(provider, operation).Observe(duration.Seconds())
        delete(m.startTimes, key)
    }
}
```

### Performance Dashboard Configuration
```yaml
# performance-dashboard.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: vitistack-performance-dashboard
  namespace: vitistack-system
data:
  dashboard.json: |
    {
      "dashboard": {
        "id": null,
        "title": "VitiStack Performance Dashboard",
        "tags": ["vitistack", "performance"],
        "timezone": "browser",
        "panels": [
          {
            "id": 1,
            "title": "Reconciliation Performance",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.50, rate(vitistack_reconcile_duration_seconds_bucket[5m]))",
                "legendFormat": "50th percentile"
              },
              {
                "expr": "histogram_quantile(0.95, rate(vitistack_reconcile_duration_seconds_bucket[5m]))",
                "legendFormat": "95th percentile"
              },
              {
                "expr": "histogram_quantile(0.99, rate(vitistack_reconcile_duration_seconds_bucket[5m]))",
                "legendFormat": "99th percentile"
              }
            ]
          },
          {
            "id": 2,
            "title": "Queue Depth",
            "type": "graph",
            "targets": [
              {
                "expr": "vitistack_queue_depth",
                "legendFormat": "{{ controller }} - {{ queue_type }}"
              }
            ]
          },
          {
            "id": 3,
            "title": "Cache Hit Rate",
            "type": "stat",
            "targets": [
              {
                "expr": "rate(vitistack_cache_hits_total[5m]) / (rate(vitistack_cache_hits_total[5m]) + rate(vitistack_cache_misses_total[5m])) * 100",
                "legendFormat": "Hit Rate %"
              }
            ]
          },
          {
            "id": 4,
            "title": "API Call Performance",
            "type": "graph",
            "targets": [
              {
                "expr": "histogram_quantile(0.95, rate(vitistack_api_call_duration_seconds_bucket[5m]))",
                "legendFormat": "{{ provider }} - {{ operation }}"
              }
            ]
          },
          {
            "id": 5,
            "title": "Resource Utilization",
            "type": "graph",
            "targets": [
              {
                "expr": "vitistack_resource_utilization_percent",
                "legendFormat": "{{ resource_type }} in {{ datacenter }}"
              }
            ]
          }
        ]
      }
    }
```

## Best Practices

### Performance Best Practices Checklist

#### Controller Optimization
- ✅ Use batch processing for bulk operations
- ✅ Implement proper caching strategies
- ✅ Optimize resource allocation (CPU/Memory)
- ✅ Use connection pooling for external APIs
- ✅ Implement circuit breakers for external dependencies
- ✅ Use worker pools for concurrent processing
- ✅ Minimize memory allocations in hot paths
- ✅ Implement proper garbage collection tuning

#### Resource Management
- ✅ Set appropriate resource limits and requests
- ✅ Use horizontal and vertical pod autoscaling
- ✅ Implement resource quotas and limits
- ✅ Monitor resource utilization continuously
- ✅ Use node affinity for controller placement
- ✅ Implement proper cleanup of unused resources

#### Networking Optimization
- ✅ Use HTTP/2 where possible
- ✅ Implement request batching
- ✅ Use connection keep-alive
- ✅ Optimize DNS resolution
- ✅ Implement proper timeout handling
- ✅ Use compression for large payloads

#### Storage Performance
- ✅ Use efficient serialization formats
- ✅ Implement write-through caching
- ✅ Optimize database queries
- ✅ Use connection pooling for databases
- ✅ Implement proper indexing strategies

### Performance Testing Framework
```bash
#!/bin/bash
# performance-test-suite.sh

echo "Starting VitiStack performance test suite..."

# Test 1: Reconciliation Performance
echo "Test 1: Reconciliation Performance"
kubectl apply -f test/performance/high-load-scenario.yaml
time kubectl wait --for=condition=Ready datacenters --all --timeout=600s

# Test 2: Scaling Performance
echo "Test 2: Scaling Performance"
kubectl scale deployment vitistack-controller --replicas=10 -n vitistack-system
kubectl wait --for=condition=Available deployment/vitistack-controller -n vitistack-system --timeout=300s

# Test 3: Cache Performance
echo "Test 3: Cache Performance"
curl -s http://controller-metrics:8080/metrics | grep cache_hit_rate

# Test 4: API Performance
echo "Test 4: API Performance"
ab -n 1000 -c 10 http://vitistack-webhook:8443/validate

# Test 5: Resource Utilization
echo "Test 5: Resource Utilization"
kubectl top pods -n vitistack-system
kubectl top nodes

echo "Performance test suite completed"
```

This comprehensive performance optimization guide provides detailed strategies and implementations for maximizing the performance of VitiStack CRDs. It covers all aspects from controller optimization to resource management, caching strategies, and monitoring, ensuring optimal performance in production environments.

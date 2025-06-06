package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// Datacenter phase constants
const (
	DatacenterPhaseInitializing = "Initializing"
	DatacenterPhaseProvisioning = "Provisioning"
	DatacenterPhaseReady        = "Ready"
	DatacenterPhaseDegraded     = "Degraded"
	DatacenterPhaseDeleting     = "Deleting"
	DatacenterPhaseFailed       = "Failed"
)

// Datacenter condition types
const (
	DatacenterConditionReady             = "Ready"
	DatacenterConditionProvidersHealthy  = "ProvidersHealthy"
	DatacenterConditionNetworkingReady   = "NetworkingReady"
	DatacenterConditionMonitoringReady   = "MonitoringReady"
	DatacenterConditionBackupReady       = "BackupReady"
	DatacenterConditionSecurityCompliant = "SecurityCompliant"
	DatacenterConditionQuotaAvailable    = "QuotaAvailable"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Datacenter is the Schema for the Datacenters API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=datacenters,scope=Namespaced,shortName=dc
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Region",type=string,JSONPath=`.spec.region`
// +kubebuilder:printcolumn:name="Machine Providers",type=integer,JSONPath=`.status.machineProviderCount`
// +kubebuilder:printcolumn:name="K8s Providers",type=integer,JSONPath=`.status.kubernetesProviderCount`
// +kubebuilder:printcolumn:name="Ready",type=string,JSONPath=`.status.conditions[?(@.type=="Ready")].status`
// +kubebuilder:printcolumn:name="Age",type=date,JSONPath=`.metadata.creationTimestamp`
type Datacenter struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   DatacenterSpec   `json:"spec,omitempty"`
	Status DatacenterStatus `json:"status,omitempty"`
}

// DatacenterSpec defines the desired state of Datacenter
type DatacenterSpec struct {
	// DisplayName is the human-readable name for the datacenter
	// +kubebuilder:validation:Required
	DisplayName string `json:"displayName"`

	// Description provides additional context about the datacenter
	// +kubebuilder:validation:Optional
	Description string `json:"description,omitempty"`

	// Region specifies the geographical region where the datacenter is located
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=0
	Region string `json:"region"`

	// Zone specifies the availability zone within the region (optional)
	// +kubebuilder:validation:Optional
	Zone string `json:"zone,omitempty"`

	// Location provides detailed location information
	// +kubebuilder:validation:Optional
	Location DatacenterLocation `json:"location,omitempty"`

	// MachineProviders lists the machine providers available in this datacenter
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinItems=0
	MachineProviders []DatacenterProviderReference `json:"machineProviders"`

	// KubernetesProviders lists the Kubernetes providers available in this datacenter
	// +kubebuilder:validation:Optional
	KubernetesProviders []DatacenterProviderReference `json:"kubernetesProviders,omitempty"`

	// Networking defines the network configuration for the datacenter
	// +kubebuilder:validation:Optional
	Networking DatacenterNetworking `json:"networking,omitempty"`

	// Security defines security policies and compliance requirements
	// +kubebuilder:validation:Optional
	Security DatacenterSecurity `json:"security,omitempty"`

	// Monitoring configures monitoring and observability for the datacenter
	// +kubebuilder:validation:Optional
	Monitoring DatacenterMonitoring `json:"monitoring,omitempty"`

	// Backup configures backup and disaster recovery policies
	// +kubebuilder:validation:Optional
	Backup DatacenterBackup `json:"backup,omitempty"`

	// ResourceQuotas define resource limits for the datacenter
	// +kubebuilder:validation:Optional
	ResourceQuotas DatacenterResourceQuotas `json:"resourceQuotas,omitempty"`

	// Tags for organizing and categorizing datacenters
	// +kubebuilder:validation:Optional
	Tags map[string]string `json:"tags,omitempty"`
}

// DatacenterLocation provides detailed location information
type DatacenterLocation struct {
	// Country where the datacenter is located
	// +kubebuilder:validation:Optional
	Country string `json:"country,omitempty"`

	// City where the datacenter is located
	// +kubebuilder:validation:Optional
	City string `json:"city,omitempty"`

	// Address of the datacenter
	// +kubebuilder:validation:Optional
	Address string `json:"address,omitempty"`

	// Coordinates for the datacenter location
	// +kubebuilder:validation:Optional
	Coordinates DatacenterCoordinates `json:"coordinates,omitempty"`
}

// DatacenterCoordinates defines geographical coordinates
type DatacenterCoordinates struct {
	// Latitude coordinate (-90 to 90)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Pattern=`^-?([0-8]?[0-9](\.[0-9]+)?|90(\.0+)?)$`
	Latitude string `json:"latitude,omitempty"`

	// Longitude coordinate (-180 to 180)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Pattern=`^-?(1[0-7][0-9](\.[0-9]+)?|180(\.0+)?|[0-9]?[0-9](\.[0-9]+)?)$`
	Longitude string `json:"longitude,omitempty"`
}

// DatacenterProviderReference references a provider available in this datacenter
type DatacenterProviderReference struct {
	// Name of the provider resource
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinLength=1
	Name string `json:"name"`

	// Namespace where the provider resource is located
	// +kubebuilder:validation:Optional
	Namespace string `json:"namespace,omitempty"`

	// Priority defines the preference order for this provider (1 = highest priority)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	Priority int32 `json:"priority,omitempty"`

	// Enabled indicates if this provider is currently active
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Configuration provides provider-specific settings for this datacenter
	// +kubebuilder:validation:Optional
	Configuration map[string]string `json:"configuration,omitempty"`
}

// DatacenterNetworking defines network configuration
type DatacenterNetworking struct {
	// VPCs define the virtual private clouds available
	// +kubebuilder:validation:Optional
	VPCs []DatacenterVPC `json:"vpcs,omitempty"`

	// LoadBalancers define available load balancer configurations
	// +kubebuilder:validation:Optional
	LoadBalancers []DatacenterLoadBalancer `json:"loadBalancers,omitempty"`

	// DNS configuration for the datacenter
	// +kubebuilder:validation:Optional
	DNS DatacenterDNS `json:"dns,omitempty"`

	// Firewall rules and security groups
	// +kubebuilder:validation:Optional
	Firewall DatacenterFirewall `json:"firewall,omitempty"`
}

// DatacenterVPC defines a virtual private cloud
type DatacenterVPC struct {
	// Name of the VPC
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// CIDR block for the VPC
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern=`^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$`
	CIDR string `json:"cidr"`

	// Subnets within the VPC
	// +kubebuilder:validation:Optional
	Subnets []DatacenterSubnet `json:"subnets,omitempty"`

	// Default indicates if this is the default VPC
	// +kubebuilder:validation:Optional
	Default bool `json:"default,omitempty"`
}

// DatacenterSubnet defines a subnet within a VPC
type DatacenterSubnet struct {
	// Name of the subnet
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// CIDR block for the subnet
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Pattern=`^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$`
	CIDR string `json:"cidr"`

	// Zone where the subnet is located
	// +kubebuilder:validation:Optional
	Zone string `json:"zone,omitempty"`

	// Public indicates if this subnet has internet access
	// +kubebuilder:validation:Optional
	Public bool `json:"public,omitempty"`
}

// DatacenterLoadBalancer defines load balancer configuration
type DatacenterLoadBalancer struct {
	// Name of the load balancer
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Type of load balancer (application, network, classic)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=application;network;classic
	Type string `json:"type"`

	// Scheme defines if the load balancer is internet-facing or internal
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Enum=internet-facing;internal
	// +kubebuilder:default=internet-facing
	Scheme string `json:"scheme,omitempty"`
}

// DatacenterDNS defines DNS configuration
type DatacenterDNS struct {
	// Servers list DNS server addresses
	// +kubebuilder:validation:Optional
	Servers []string `json:"servers,omitempty"`

	// Domain is the default domain for the datacenter
	// +kubebuilder:validation:Optional
	Domain string `json:"domain,omitempty"`

	// SearchDomains for DNS resolution
	// +kubebuilder:validation:Optional
	SearchDomains []string `json:"searchDomains,omitempty"`
}

// DatacenterFirewall defines firewall configuration
type DatacenterFirewall struct {
	// DefaultPolicy for traffic (allow, deny)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Enum=allow;deny
	// +kubebuilder:default=deny
	DefaultPolicy string `json:"defaultPolicy,omitempty"`

	// Rules define specific firewall rules
	// +kubebuilder:validation:Optional
	Rules []DatacenterFirewallRule `json:"rules,omitempty"`
}

// DatacenterFirewallRule defines a firewall rule
type DatacenterFirewallRule struct {
	// Name of the rule
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Action to take (allow, deny)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=allow;deny
	Action string `json:"action"`

	// Protocol (tcp, udp, icmp, all)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Enum=tcp;udp;icmp;all
	// +kubebuilder:default=tcp
	Protocol string `json:"protocol,omitempty"`

	// Port or port range
	// +kubebuilder:validation:Optional
	Port string `json:"port,omitempty"`

	// Source CIDR or IP range
	// +kubebuilder:validation:Optional
	Source string `json:"source,omitempty"`

	// Destination CIDR or IP range
	// +kubebuilder:validation:Optional
	Destination string `json:"destination,omitempty"`
}

// DatacenterSecurity defines security policies
type DatacenterSecurity struct {
	// ComplianceFrameworks that must be adhered to
	// +kubebuilder:validation:Optional
	ComplianceFrameworks []string `json:"complianceFrameworks,omitempty"`

	// Encryption requirements
	// +kubebuilder:validation:Optional
	Encryption DatacenterEncryption `json:"encryption,omitempty"`

	// AccessControl policies
	// +kubebuilder:validation:Optional
	AccessControl DatacenterAccessControl `json:"accessControl,omitempty"`

	// AuditLogging configuration
	// +kubebuilder:validation:Optional
	AuditLogging DatacenterAuditLogging `json:"auditLogging,omitempty"`
}

// DatacenterEncryption defines encryption requirements
type DatacenterEncryption struct {
	// AtRest indicates if data at rest must be encrypted
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	AtRest bool `json:"atRest,omitempty"`

	// InTransit indicates if data in transit must be encrypted
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	InTransit bool `json:"inTransit,omitempty"`

	// KeyManagement service to use
	// +kubebuilder:validation:Optional
	KeyManagement string `json:"keyManagement,omitempty"`
}

// DatacenterAccessControl defines access control policies
type DatacenterAccessControl struct {
	// RBAC indicates if role-based access control is required
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	RBAC bool `json:"rbac,omitempty"`

	// MFA indicates if multi-factor authentication is required
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=false
	MFA bool `json:"mfa,omitempty"`

	// AllowedUsers list users who can access resources in this datacenter
	// +kubebuilder:validation:Optional
	AllowedUsers []string `json:"allowedUsers,omitempty"`

	// AllowedGroups list groups who can access resources in this datacenter
	// +kubebuilder:validation:Optional
	AllowedGroups []string `json:"allowedGroups,omitempty"`
}

// DatacenterAuditLogging defines audit logging configuration
type DatacenterAuditLogging struct {
	// Enabled indicates if audit logging is enabled
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// RetentionDays for audit logs
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=2555
	// +kubebuilder:default=90
	RetentionDays int32 `json:"retentionDays,omitempty"`

	// Destination for audit logs (local, s3, azure, gcs)
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Enum=local;s3;azure;gcs;elasticsearch
	Destination string `json:"destination,omitempty"`
}

// DatacenterMonitoring defines monitoring configuration
type DatacenterMonitoring struct {
	// Enabled indicates if monitoring is enabled
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// MetricsRetentionDays for storing metrics
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:validation:Maximum=365
	// +kubebuilder:default=30
	MetricsRetentionDays int32 `json:"metricsRetentionDays,omitempty"`

	// AlertingEnabled indicates if alerting is configured
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	AlertingEnabled bool `json:"alertingEnabled,omitempty"`

	// AlertReceivers list contact points for alerts
	// +kubebuilder:validation:Optional
	AlertReceivers []string `json:"alertReceivers,omitempty"`

	// CustomDashboards list custom monitoring dashboards
	// +kubebuilder:validation:Optional
	CustomDashboards []string `json:"customDashboards,omitempty"`
}

// DatacenterBackup defines backup and disaster recovery
type DatacenterBackup struct {
	// Enabled indicates if backup is enabled
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=true
	Enabled bool `json:"enabled,omitempty"`

	// Schedule for automated backups (cron format)
	// +kubebuilder:validation:Optional
	// +kubebuilder:default="0 2 * * *"
	Schedule string `json:"schedule,omitempty"`

	// RetentionPolicy for backups
	// +kubebuilder:validation:Optional
	RetentionPolicy DatacenterBackupRetention `json:"retentionPolicy,omitempty"`

	// Destinations where backups are stored
	// +kubebuilder:validation:Optional
	Destinations []DatacenterBackupDestination `json:"destinations,omitempty"`

	// DisasterRecovery configuration
	// +kubebuilder:validation:Optional
	DisasterRecovery DatacenterDisasterRecovery `json:"disasterRecovery,omitempty"`
}

// DatacenterBackupRetention defines backup retention policies
type DatacenterBackupRetention struct {
	// Daily backups to keep
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=7
	Daily int32 `json:"daily,omitempty"`

	// Weekly backups to keep
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=4
	Weekly int32 `json:"weekly,omitempty"`

	// Monthly backups to keep
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	// +kubebuilder:default=12
	Monthly int32 `json:"monthly,omitempty"`
}

// DatacenterBackupDestination defines backup storage destination
type DatacenterBackupDestination struct {
	// Name of the backup destination
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Type of backup destination (s3, azure, gcs, local)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=s3;azure;gcs;local;nfs
	Type string `json:"type"`

	// Configuration for the backup destination
	// +kubebuilder:validation:Optional
	Configuration map[string]string `json:"configuration,omitempty"`

	// Encryption settings for backup destination
	// +kubebuilder:validation:Optional
	Encryption bool `json:"encryption,omitempty"`
}

// DatacenterDisasterRecovery defines disaster recovery configuration
type DatacenterDisasterRecovery struct {
	// Enabled indicates if disaster recovery is configured
	// +kubebuilder:validation:Optional
	// +kubebuilder:default=false
	Enabled bool `json:"enabled,omitempty"`

	// TargetDatacenter for disaster recovery
	// +kubebuilder:validation:Optional
	TargetDatacenter string `json:"targetDatacenter,omitempty"`

	// RPO (Recovery Point Objective) in minutes
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	RPOMinutes int32 `json:"rpoMinutes,omitempty"`

	// RTO (Recovery Time Objective) in minutes
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	RTOMinutes int32 `json:"rtoMinutes,omitempty"`
}

// DatacenterResourceQuotas defines resource limits
type DatacenterResourceQuotas struct {
	// MaxMachines limits the number of machines
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxMachines int32 `json:"maxMachines,omitempty"`

	// MaxClusters limits the number of Kubernetes clusters
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxClusters int32 `json:"maxClusters,omitempty"`

	// MaxCPUCores limits total CPU cores
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxCPUCores int32 `json:"maxCPUCores,omitempty"`

	// MaxMemoryGB limits total memory in GB
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxMemoryGB int32 `json:"maxMemoryGB,omitempty"`

	// MaxStorageGB limits total storage in GB
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxStorageGB int32 `json:"maxStorageGB,omitempty"`

	// MaxNetworkInterfaces limits network interfaces
	// +kubebuilder:validation:Optional
	// +kubebuilder:validation:Minimum=1
	MaxNetworkInterfaces int32 `json:"maxNetworkInterfaces,omitempty"`
}

// DatacenterStatus defines the observed state of Datacenter
type DatacenterStatus struct {
	// Phase represents the current phase of the datacenter
	// +kubebuilder:validation:Optional
	Phase string `json:"phase,omitempty"`

	// Conditions represent the latest available observations of datacenter state
	// +kubebuilder:validation:Optional
	Conditions []metav1.Condition `json:"conditions,omitempty"`

	// MachineProviderCount is the number of active machine providers
	// +kubebuilder:validation:Optional
	MachineProviderCount int32 `json:"machineProviderCount,omitempty"`

	// KubernetesProviderCount is the number of active Kubernetes providers
	// +kubebuilder:validation:Optional
	KubernetesProviderCount int32 `json:"kubernetesProviderCount,omitempty"`

	// ActiveMachines is the number of active machines in the datacenter
	// +kubebuilder:validation:Optional
	ActiveMachines int32 `json:"activeMachines,omitempty"`

	// ActiveClusters is the number of active Kubernetes clusters
	// +kubebuilder:validation:Optional
	ActiveClusters int32 `json:"activeClusters,omitempty"`

	// ResourceUsage shows current resource utilization
	// +kubebuilder:validation:Optional
	ResourceUsage DatacenterResourceUsage `json:"resourceUsage,omitempty"`

	// ProviderStatuses shows the status of each provider
	// +kubebuilder:validation:Optional
	ProviderStatuses []DatacenterProviderStatus `json:"providerStatuses,omitempty"`

	// LastReconcileTime is when the datacenter was last reconciled
	// +kubebuilder:validation:Optional
	LastReconcileTime *metav1.Time `json:"lastReconcileTime,omitempty"`

	// ObservedGeneration reflects the generation of the most recently observed Datacenter
	// +kubebuilder:validation:Optional
	ObservedGeneration int64 `json:"observedGeneration,omitempty"`
}

// DatacenterResourceUsage shows current resource utilization
type DatacenterResourceUsage struct {
	// CPUCoresUsed shows used CPU cores
	// +kubebuilder:validation:Optional
	CPUCoresUsed int32 `json:"cpuCoresUsed,omitempty"`

	// CPUCoresTotal shows total available CPU cores
	// +kubebuilder:validation:Optional
	CPUCoresTotal int32 `json:"cpuCoresTotal,omitempty"`

	// MemoryGBUsed shows used memory in GB
	// +kubebuilder:validation:Optional
	MemoryGBUsed int32 `json:"memoryGBUsed,omitempty"`

	// MemoryGBTotal shows total available memory in GB
	// +kubebuilder:validation:Optional
	MemoryGBTotal int32 `json:"memoryGBTotal,omitempty"`

	// StorageGBUsed shows used storage in GB
	// +kubebuilder:validation:Optional
	StorageGBUsed int32 `json:"storageGBUsed,omitempty"`

	// StorageGBTotal shows total available storage in GB
	// +kubebuilder:validation:Optional
	StorageGBTotal int32 `json:"storageGBTotal,omitempty"`

	// NetworkInterfacesUsed shows used network interfaces
	// +kubebuilder:validation:Optional
	NetworkInterfacesUsed int32 `json:"networkInterfacesUsed,omitempty"`

	// NetworkInterfacesTotal shows total available network interfaces
	// +kubebuilder:validation:Optional
	NetworkInterfacesTotal int32 `json:"networkInterfacesTotal,omitempty"`
}

// DatacenterProviderStatus shows the status of a provider in the datacenter
type DatacenterProviderStatus struct {
	// Name of the provider
	// +kubebuilder:validation:Required
	Name string `json:"name"`

	// Type of provider (machine, kubernetes)
	// +kubebuilder:validation:Required
	// +kubebuilder:validation:Enum=machine;kubernetes
	Type string `json:"type"`

	// Phase of the provider (Ready, NotReady, Failed)
	// +kubebuilder:validation:Optional
	Phase string `json:"phase,omitempty"`

	// Healthy indicates if the provider is healthy
	// +kubebuilder:validation:Optional
	Healthy bool `json:"healthy,omitempty"`

	// LastHealthCheck is when the provider was last health checked
	// +kubebuilder:validation:Optional
	LastHealthCheck *metav1.Time `json:"lastHealthCheck,omitempty"`

	// Message provides additional status information
	// +kubebuilder:validation:Optional
	Message string `json:"message,omitempty"`

	// ResourcesManaged shows resources managed by this provider
	// +kubebuilder:validation:Optional
	ResourcesManaged int32 `json:"resourcesManaged,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// DatacenterList contains a list of Datacenter
type DatacenterList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Datacenter `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Datacenter{}, &DatacenterList{})
}

package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// LoadBalancer is the Schema for the LoadBalancer API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=loadbalancers,scope=Namespaced,shortName=lb
// +kubebuilder:printcolumn:name="DatacenterName",type=string,JSONPath=`.spec.datacenterName`
// +kubebuilder:printcolumn:name="ClusterName",type=string,JSONPath=`.spec.clusterName`
// +kubebuilder:printcolumn:name="Provider",type=string,JSONPath=`.spec.provider`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.status`
// +kubebuilder:printcolumn:name="Created",type=string,JSONPath=`.status.created`,description="Creation Timestamp"
type LoadBalancer struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec LoadBalancerSpec `json:"spec,omitempty"`

	Status LoadBalancerStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// MachineList contains a list of Machine
type LoadBalancerList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []LoadBalancer `json:"items"`
}

type LoadBalancerSpec struct {
	// +kubebuilder:validation:Required
	DatacenterName string `json:"datacenterName,omitempty"`

	// +kubebuilder:validation:Required
	ClusterName string `json:"clusterName,omitempty"`

	// +kubebuilder:validation:Required
	Provider string `json:"provider,omitempty"`

	// +kubebuilder:validation:Optional
	// +kubebuilder:default:=first-alive
	// +kubebuilder:validation:Enum=round-robin;least-session;first-alive
	// round-robin, least-session, first-alive
	Method string `json:"method,omitempty"`

	// +kubebuilder:validation:Required
	// +kubebuilder:validation:MinItems:=1
	// example control plane ips
	PoolMembers []string `json:"poolMembers,omitempty"`
}

type LoadBalancerStatus struct {
	Conditions []metav1.Condition `json:"conditions,omitempty"`
	Phase      string             `json:"phase,omitempty"`
	Status     string             `json:"status,omitempty"`
	Message    string             `json:"message,omitempty"`
	Created    metav1.Time        `json:"created,omitempty"`

	LoadBalancerIps []string `json:"loadBalancerIps,omitempty"`
	Method          string   `json:"method,omitempty"`
	PoolMembers     []string `json:"poolMembers,omitempty"`
}

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

	LoadBalancerIpv4s []string `json:"loadBalancerIpv4,omitempty"`

	LoadBalancerIpv6s []string `json:"loadBalancerIpv6,omitempty"`
}

type LoadBalancerStatus struct {
	Conditions []metav1.Condition `json:"conditions,omitempty"`
	Phase      string             `json:"phase,omitempty"`
	Status     string             `json:"status,omitempty"`
	Message    string             `json:"message,omitempty"`
	Created    metav1.Time        `json:"created,omitempty"`
}

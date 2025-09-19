package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// NetworkNamespace is the Schema for the NetworkNamespace API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=networknamespaces,scope=Namespaced,shortName=nn
// +kubebuilder:printcolumn:name="Name",type=string,JSONPath=`.spec.name`
// +kubebuilder:printcolumn:name="DatacenterName",type=string,JSONPath=`.spec.datacenterName`
// +kubebuilder:printcolumn:name="Phase",type=string,JSONPath=`.status.phase`
// +kubebuilder:printcolumn:name="Status",type=string,JSONPath=`.status.status`
// +kubebuilder:printcolumn:name="Created",type=string,JSONPath=`.status.created`,description="Creation Timestamp"
type NetworkNamespace struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NetworkNamespaceSpec   `json:"spec,omitempty"`
	Status NetworkNamespaceStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// NetworkNamespaceList contains a list of NetworkNamespace
type NetworkNamespaceList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []NetworkNamespace `json:"items"`
}

type NetworkNamespaceSpec struct {
	// +kubebuilder:validation:Required
	DatacenterName string `json:"datacenterName,omitempty"` // <country>-<region>-<availability zone> ex: no-west-az1
	// +kubebuilder:validation:Required
	Name string `json:"name,omitempty"` // <unique name per availability zone> ex: my-name
	// +kubebuilder:validation:Required
	Provider string `json:"provider,omitempty"`
}

type NetworkNamespaceStatus struct {
	Conditions []metav1.Condition `json:"conditions,omitempty"`
	Phase      string             `json:"phase,omitempty"`
	Status     string             `json:"status,omitempty"`
	Message    string             `json:"message,omitempty"`
	Created    metav1.Time        `json:"created,omitempty"`

	NamespaceID  string `json:"namespace_id,omitempty"`
	Name         string `json:"name,omitempty"`
	IPv4Prefix   string `json:"ipv4_prefix,omitempty"`
	IPv6Prefix   string `json:"ipv6_prefix,omitempty"`
	IPv4EgressIP string `json:"ipv4_egress_ip,omitempty"`
	IPv6EgressIP string `json:"ipv6_egress_ip,omitempty"`
	VlanID       int    `json:"vlan_id,omitempty"`

	AssociatedKubernetesClusterIDs []string `json:"associated_kubernetes_cluster_ids,omitempty"`
}

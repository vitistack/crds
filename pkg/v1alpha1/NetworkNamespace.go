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
type NetworkNamespace struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NetworkNamespaceSpec   `json:"spec,omitempty"`
	Status NetworkNamespaceStatus `json:"status,omitempty"`
}

type NetworkNamespaceSpec struct {
	DatacenterName string `json:"datacenterName,omitempty"` // <country>-<region>-<availability zone> ex: no-west-az1
	Name           string `json:"name,omitempty"`           // <unique name per availability zone> ex: my-name
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
	Subnet       string `json:"subnet,omitempty"`

	AssociatedKubernetesClusterIDs []string `json:"associated_kubernetes_cluster_ids,omitempty"`
}

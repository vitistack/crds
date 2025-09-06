package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// NetworkConfiguration is the Schema for the NetworkConfiguration API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=networkconfigurations,scope=Namespaced,shortName=nc
type NetworkConfiguration struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   NetworkConfigurationSpec   `json:"spec,omitempty"`
	Status NetworkConfigurationStatus `json:"status,omitempty"`
}

type NetworkConfigurationSpec struct {
	Name              string              `json:"name,omitempty"`
	NetworkInterfaces []NetworkInterfaces `json:"networkInterfaces,omitempty"`
}

type NetworkConfigurationStatus struct {
	Conditions        []metav1.Condition  `json:"conditions,omitempty"`
	Phase             string              `json:"phase,omitempty"`
	Status            string              `json:"status,omitempty"`
	Message           string              `json:"message,omitempty"`
	Created           metav1.Time         `json:"created,omitempty"`
	NetworkInterfaces []NetworkInterfaces `json:"networkInterfaces,omitempty"`
}

type NetworkInterfaces struct {
	// Name
	Name string `json:"name,omitempty"`
	// Mac address
	MacAddress string `json:"macAddress,omitempty"`
	// IPv4 addresses
	IPv4Addresses []string `json:"ipv4Addresses,omitempty"`
	// IPv6 addresses
	IPv6Addresses []string `json:"ipv6Addresses,omitempty"`
	// Vlan
	Vlan string `json:"vlan,omitempty"`
	// Subnet
	IPv4Subnet string `json:"ipv4Subnet,omitempty"`
	// Subnet for ipv6
	IPv6Subnet string `json:"ipv6Subnet,omitempty"`
	// Gateway
	IPv4Gateway string `json:"ipv4Gateway,omitempty"`
	// Gateway for ipv6
	IPv6Gateway string `json:"ipv6Gateway,omitempty"`
	// DNS
	DNS []string `json:"dns,omitempty"`
	// DHCP reserved in dchp server(s)
	DHCPReserved bool `json:"dhcpReserved,omitempty"`
}

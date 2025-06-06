package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Machine is the Schema for the Machines API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=machines,scope=Namespaced,shortName=m
type Machine struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   MachineSpec   `json:"spec,omitempty"`
	Status MachineStatus `json:"status,omitempty"`
}

type MachineSpec struct {
	// The name of the machine
	Name string `json:"name"`
	// The type of the machine
	Type string `json:"type"`
}

type MachineStatus struct {
	// The unique identifier for the machine
	MachineID string `json:"machineID"`

	// systemd identifier for the machine
	SystemdID string `json:"systemdID"`

	// The current state of the machine
	State string `json:"state"`

	// The current status of the machine
	Status string `json:"status"`

	// The last time the machine status was updated
	LastUpdated metav1.Time `json:"lastUpdated"`

	// The provider of the machine
	Provider string `json:"provider"`

	// The region where the machine is located
	Region string `json:"region"`

	// The zone where the machine is located
	Zone string `json:"zone"`

	// The IP address of the machine
	IPAddress []string `json:"ipAddress"`

	Ipv6Address []string `json:"ipv6Address"`

	// Thme machine's cpu architecture
	Architecture string `json:"architecture"`

	// The machine's operating system
	OperatingSystem string `json:"operatingSystem"`

	// The machine's operating system version
	OperatingSystemVersion string `json:"operatingSystemVersion"`

	// The machine's kernel version
	KernelVersion string `json:"kernelVersion"`

	// The machine's hostname
	Hostname string `json:"hostname"`

	// the machine's cpus
	CPUs int `json:"cpus"`

	// The machine's memory in bytes
	Memory int64 `json:"memory"`

	// The machine's disk size in bytes
	Disks []MachineDisk `json:"disks"`
}

type MachineDisk struct {
	// The disk's name
	Name string `json:"name"`
	// The disk's size in bytes
	Size int64 `json:"size"`
	// The disk's type (e.g., SSD, HDD)
	Type string `json:"type"`
	// The disk's mount point
	MountPoint string `json:"mountPoint"`
	// The disk's filesystem type (e.g., ext4, xfs)
	FilesystemType string `json:"filesystemType"`
	// The disk's UUID
	UUID string `json:"uuid"`
	// The disk's label
	Label string `json:"label"`
	// The disk's serial number
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// MachineList contains a list of Machine
type MachineList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Machine `json:"items"`
}

func init() {
	SchemeBuilder.Register(&Machine{}, &MachineList{})
}

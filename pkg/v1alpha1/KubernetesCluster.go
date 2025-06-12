package v1alpha1

import (
	"github.com/NorskHelsenett/ror/pkg/rorresources/rortypes"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// +k8s:deepcopy-gen=false

// KubernetesCluster is the Schema for the Machines API
// +kubebuilder:object:root=true
// +kubebuilder:subresource:status
// +kubebuilder:resource:path=kubernetesclusters,scope=Namespaced,shortName=kc
type KubernetesCluster struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec rortypes.KubernetesClusterSpec `json:"spec,omitempty"`

	Status rortypes.KubernetesClusterStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object
// +k8s:deepcopy-gen=false
// MachineList contains a list of Machine
type KubernetesClusterList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []KubernetesCluster `json:"items"`
}

func init() {
	SchemeBuilder.Register(&KubernetesCluster{}, &KubernetesClusterList{})
}

// Custom DeepCopyInto implementation to handle rortypes fields
func (in *KubernetesCluster) DeepCopyInto(out *KubernetesCluster) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ObjectMeta.DeepCopyInto(&out.ObjectMeta)
	// Use simple assignment for rortypes fields since they don't have DeepCopyInto methods
	out.Spec = in.Spec
	out.Status = in.Status
}

// Custom DeepCopy implementation
func (in *KubernetesCluster) DeepCopy() *KubernetesCluster {
	if in == nil {
		return nil
	}
	out := new(KubernetesCluster)
	in.DeepCopyInto(out)
	return out
}

// Custom DeepCopyObject implementation for runtime.Object interface
func (in *KubernetesCluster) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

// Custom DeepCopyInto implementation for KubernetesClusterList
func (in *KubernetesClusterList) DeepCopyInto(out *KubernetesClusterList) {
	*out = *in
	out.TypeMeta = in.TypeMeta
	in.ListMeta.DeepCopyInto(&out.ListMeta)
	if in.Items != nil {
		inItems, outItems := &in.Items, &out.Items
		*outItems = make([]KubernetesCluster, len(*inItems))
		for i := range *inItems {
			(*inItems)[i].DeepCopyInto(&(*outItems)[i])
		}
	}
}

// Custom DeepCopy implementation for KubernetesClusterList
func (in *KubernetesClusterList) DeepCopy() *KubernetesClusterList {
	if in == nil {
		return nil
	}
	out := new(KubernetesClusterList)
	in.DeepCopyInto(out)
	return out
}

// Custom DeepCopyObject implementation for KubernetesClusterList
func (in *KubernetesClusterList) DeepCopyObject() runtime.Object {
	if c := in.DeepCopy(); c != nil {
		return c
	}
	return nil
}

# Vitistack CRDs

Vitistack’s Kubernetes CustomResourceDefinitions (CRDs) and typed Go APIs.

Provided CRDs (see docs for details):

- Vitistack
- Machine, MachineProvider
- KubernetesCluster, KubernetesProvider
- NetworkConfiguration, NetworkNamespace

## Quick start

- Generate CRDs

```sh
make manifests
```

- Install CRDs into your cluster

```sh
make install-crds
```

- Verify

```sh
kubectl get crd | grep vitistack.io
```

- Try examples

```sh
kubectl apply -f examples/machine-example.yaml
kubectl apply -f examples/kubernetes-provider-example.yaml
```

## Development

Prerequisites:

- Go (as in go.mod, currently 1.25)
- make, kubectl

Common tasks:

- Help: `make help`
- Generate objects + CRDs: `make generate` (or `make manifests` / `make gen-deepcopy`)
- Sanitize CRDs (strip unsupported integer formats): `make sanitize-crds`
- Verify sanitized CRDs: `make verify-crds`
- Format/Vet/Lint: `make fmt` | `make vet` | `make lint`
- Tests: `make test`
- Update deps: `make update-deps` (or `make deps`)
- Security scan: `make go-security-scan`
- Uninstall CRDs: `make uninstall-crds`

CRDs are emitted to the `crds/` folder.

## Using the Go types

Import the API package for typed access:

```go
import (
    v1alpha1 "github.com/vitistack/crds/pkg/v1alpha1"
    "k8s.io/apimachinery/pkg/runtime"
)

var scheme = runtime.NewScheme()
_ = v1alpha1.AddToScheme(scheme)

m := &v1alpha1.Machine{
    // fill metadata/spec
}
```

### Converting to/from unstructured

This repo provides helpers in `pkg/unstructuredutil` to convert typed objects to `unstructured.Unstructured` and back:

```go
import (
    unstructuredutil "github.com/vitistack/crds/pkg/unstructuredutil"
    v1alpha1 "github.com/vitistack/crds/pkg/v1alpha1"
)

u, err := unstructuredutil.MachineToUnstructured(&v1alpha1.Machine{/* ... */})
// ... use u with a dynamic client, etc.

typed, err := unstructuredutil.MachineFromUnstructured(u)
```

## Documentation

- Docs overview: `docs/`
  - [docs/vitistack-crd.md](./docs/vitistack-crd.md)
  - [docs/machine-crd.md](./docs/machine-crd.md)
  - [docs/machine-provider-crd.md](./docs/machine-provider-crd.md)
  - [docs/kubernetes-provider-crd.md](./docs/kubernetes-provider-crd.md)
  - [docs/api-reference.md](./docs/api-reference.md)
  - [docs/architecture.md](./docs/architecture.md)
  - [docs/operational-guide.md](./docs/operational-guide.md)
  - [docs/deployment-automation.md](./docs/deployment-automation.md)
  - [docs/performance-optimization.md](./docs/performance-optimization.md)
  - [docs/testing-guide.md](./docs/testing-guide.md)

Examples are in `examples/`.

## Contributing

- Open an issue or PR.
- Run `make lint` and `make test` before submitting.

## License

Apache 2.0 (see `LICENSE`).

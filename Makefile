# Makefile for the project
# inspired by kubebuilder.io

# Setting SHELL to bash allows bash commands to be executed by recipes.
# Options are set to exit when a recipe line exits non-zero or a piped command fails.
SHELL = /usr/bin/env bash -o pipefail
.SHELLFLAGS = -ec

## Location to install dependencies to
LOCALBIN ?= $(shell pwd)/bin
$(LOCALBIN):
	mkdir -p $(LOCALBIN)

GOLANGCI_LINT = $(LOCALBIN)/golangci-lint
CONTROLLER_GEN = $(LOCALBIN)/controller-gen

# Use the Go toolchain version declared in go.mod when building tools
GO_VERSION := $(shell awk '/^go /{print $$2}' go.mod)
GO_TOOLCHAIN := go$(GO_VERSION)
GOSEC ?= $(LOCALBIN)/gosec
GOSEC_VERSION ?= v2.22.8

##@ Help
.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


##@ Generate code and manifests

.PHONY: manifests
manifests: generate ## Generate CRD manifests
	
.PHONY: generate
generate: gen-deepcopy gen-manifests   ## Generate code and manifests.

.PHONY: gen-manifests
gen-manifests: controller-gen ## Generate manifests
	$(CONTROLLER_GEN) rbac:roleName=manager-role crd webhook paths="./..." output:crd:artifacts:config=crds
	@hack/sanitize-crds.sh crds

.PHONY: sanitize-crds
sanitize-crds: ## Sanitize generated CRDs to remove unsupported int32/int64 formats.
	hack/sanitize-crds.sh crds

.PHONY: verify-crds
verify-crds: ## Verify CRDs are sanitized (no int32/int64 format lines present).
	@set -e; \
	if grep -R --include='*.yaml' -E '^[[:space:]]*format:[[:space:]]*"?int(32|64)"?[[:space:]]*$$' crds >/dev/null; then \
	  echo "CRDs contain int32/int64 format lines. Run 'make sanitize-crds' or 'make manifests'."; \
	  exit 1; \
	else \
	  echo "CRDs are sanitized."; \
	fi

.PHONY: gen-deepcopy
gen-deepcopy: controller-gen ## Generate code
	$(CONTROLLER_GEN) object:headerFile="hack/boilerplate.go.txt" paths="./..."

##@ Build
.PHONY: build
build: ## Build the manager binary.
	go build ./...

##@ Code sanity

.PHONY: fmt
fmt: ## Run go fmt against code.
	go fmt ./...

.PHONY: vet
vet: ## Run go vet against code.
	go vet ./...

.PHONY: lint
lint: golangci-lint ## Run golangci-lint (prints a summary when clean).
	@out="$$( $(GOLANGCI_LINT) run --timeout 5m ./... --config .golangci.yml 2>&1 )"; ec=$$?; \
	if [ $$ec -ne 0 ]; then \
	  printf '%s\n' "$$out"; \
	  exit $$ec; \
	fi; \
	if [ -z "$$out" ]; then \
	  echo 'No lint issues found.'; \
	else \
	  printf '%s\n' "$$out"; \
	  count=$$(printf '%s\n' "$$out" | grep -E ':[0-9]+:[0-9]+: ' | wc -l | tr -d ' '); \
	  echo "Total issues: $$count"; \
	fi

.PHONY: lint-json
lint-json: golangci-lint ## Output lint results in JSON with issue count (requires jq for count display).
	@json="$$( $(GOLANGCI_LINT) run --timeout 5m --out-format json ./... --config .golangci.yml 2>/dev/null )"; ec=$$?; \
	if [ $$ec -ne 0 ]; then echo "Lint failed"; exit $$ec; fi; \
	if command -v jq >/dev/null 2>&1; then echo "Issue count: $$(echo "$$json" | jq '.Issues | length')"; fi; \
	echo "$$json"

##@ Tests
.PHONY: test
test: ## Run unit tests.
	go test -v ./... -coverprofile coverage.out
	go tool cover -html=coverage.out -o coverage.html

deps: ## Download and verify dependencies
	@echo "Downloading dependencies..."
	@go mod download
	@go mod verify
	@go mod tidy
	@echo "Dependencies updated!"

update-deps: ## Update dependencies
	@echo "Updating dependencies..."
	@go get -u ./...
	@go mod tidy
	@echo "Dependencies updated!"

##@ kubernetes
.PHONY: install-crds
install-crds: manifests ## Install CRDs into a Kubernetes cluster.
	kubectl apply -f crds

.PHONY: uninstall-crds
uninstall-crds: ## Uninstall CRDs from a Kubernetes cluster.
	kubectl delete -f crds

##@ Tools

CONTROLLER_TOOLS_VERSION ?= latest
GOLANGCI_LINT_VERSION ?= latest

.PHONY: controller-gen
controller-gen: $(CONTROLLER_GEN) ## Download controller-gen locally if necessary.
$(CONTROLLER_GEN): $(LOCALBIN)
	$(call go-install-tool,$(CONTROLLER_GEN),sigs.k8s.io/controller-tools/cmd/controller-gen,$(CONTROLLER_TOOLS_VERSION))

.PHONY: golangci-lint
golangci-lint: $(GOLANGCI_LINT) ## Download golangci-lint locally if necessary.
$(GOLANGCI_LINT): $(LOCALBIN)
	$(call go-install-tool,$(GOLANGCI_LINT),github.com/golangci/golangci-lint/cmd/golangci-lint,$(GOLANGCI_LINT_VERSION))

.PHONY: install-security-scanner
install-security-scanner: $(GOSEC) ## Install gosec security scanner locally (static analysis for security issues)
$(GOSEC): $(LOCALBIN)
	@set -e; echo "Attempting to install gosec $(GOSEC_VERSION)"; \
	if ! GOBIN=$(LOCALBIN) go install github.com/securego/gosec/v2/cmd/gosec@$(GOSEC_VERSION) 2>/dev/null; then \
		echo "Primary install failed, attempting install from @main (compatibility fallback)"; \
		if ! GOBIN=$(LOCALBIN) go install github.com/securego/gosec/v2/cmd/gosec@main; then \
			echo "gosec installation failed for versions $(GOSEC_VERSION) and @main"; \
			exit 1; \
		fi; \
	fi; \
	echo "gosec installed at $(GOSEC)"; \
	chmod +x $(GOSEC)

##@ Security
.PHONY: go-security-scan
go-security-scan: install-security-scanner ## Run gosec security scan (fails on findings)
	$(GOSEC) ./...

# go-install-tool will 'go install' any package with custom target and name of binary, if it doesn't exist
# $1 - target path with name of binary
# $2 - package url which can be installed
# $3 - specific version of package
define go-install-tool
@[ -f "$(1)-$(3)" ] || { \
set -e; \
package=$(2)@$(3) ;\
echo "Downloading $${package}" ;\
rm -f $(1) || true ;\
GOTOOLCHAIN=$(GO_TOOLCHAIN) GOBIN=$(LOCALBIN) go install $${package} ;\
mv $(1) $(1)-$(3) ;\
} ;\
ln -sf $(1)-$(3) $(1)
endef

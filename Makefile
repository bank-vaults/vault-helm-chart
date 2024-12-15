# A Self-Documenting Makefile: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

export PATH := $(abspath bin/):${PATH}

##@ General

# Targets commented with ## will be visible in "make help" info.
# Comments marked with ##@ will be used as categories for a group of targets.

.PHONY: help
default: help
help: ## Display this help
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Development

.PHONY: up
up: ## Start development environment
	$(KIND_BIN) create cluster

.PHONY: down
down: ## Destroy development environment
	$(KIND_BIN) delete cluster

##@ Build

.PHONY: artifacts
artifacts: helm-chart generate ## Build artifacts

.PHONY: helm-chart
helm-chart: ## Build Helm chart
	@mkdir -p build
	$(HELM_BIN) package -d build/ vault

.PHONY: generate
generate: ## Generate Helm chart documentation
	$(HELM_DOCS_BIN) -s file -c ./vault -t README.md.gotmpl

##@ Checks

.PHONY: check
check: test-acceptance lint ## Run tests and lint checks

.PHONY: test-acceptance
test-acceptance: ## Run acceptance tests
	go test -race -v -timeout 900s -tags kubeall ./test

.PHONY: lint
lint: lint-helm lint-yaml
lint: ## Run lint checks

.PHONY: lint-helm
lint-helm:
	$(HELM_BIN) lint vault

.PHONY: lint-yaml
lint-yaml:
	$(YAMLLINT_BIN) $(if ${CI},-f github,) --no-warnings .

# TODO: add support for yamllint dependency
YAMLLINT_BIN := yamllint

##@ Dependencies

deps: bin/kind bin/helm bin/helm-docs
deps: ## Install dependencies

# Dependency versions
KIND_VERSION = 0.25.0
HELM_VERSION = 3.16.3
HELM_DOCS_VERSION = 1.14.2

# Dependency binaries
KIND_BIN := kind
HELM_BIN := helm
HELM_DOCS_BIN := helm-docs

# If we have "bin" dir, use those binaries instead
ifneq ($(wildcard ./bin/.),)
	KIND_BIN := bin/$(KIND_BIN)
	HELM_BIN := bin/$(HELM_BIN)
	HELM_DOCS_BIN := bin/$(HELM_DOCS_BIN)
endif

bin/kind:
	@mkdir -p bin
	curl -Lo bin/kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m | sed -e "s/aarch64/arm64/; s/x86_64/amd64/")
	@chmod +x bin/kind

bin/helm:
	@mkdir -p bin
	curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | USE_SUDO=false HELM_INSTALL_DIR=bin DESIRED_VERSION=v${HELM_VERSION} bash

bin/helm-docs:
	@mkdir -p bin
	curl -L https://github.com/norwoodj/helm-docs/releases/download/v${HELM_DOCS_VERSION}/helm-docs_${HELM_DOCS_VERSION}_$(shell uname)_x86_64.tar.gz | tar -zOxf - helm-docs > ./bin/helm-docs
	@chmod +x bin/helm-docs

# A Self-Documenting Makefile: http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html

export PATH := $(abspath bin/):${PATH}

# Dependency versions
KIND_VERSION = 0.20.0
HELM_DOCS_VERSION = 1.11.0

.PHONY: up
up: ## Start development environment
	kind create cluster

.PHONY: stop
stop: ## Stop development environment
	# TODO: consider using k3d instead
	kind delete cluster

.PHONY: down
down: ## Destroy development environment
	kind delete cluster

.PHONY: build
build: ## Build binary
	@mkdir -p build
	go build -race -o build/manager ./cmd/manager

.PHONY: artifacts
artifacts: helm-chart
artifacts: ## Build artifacts

.PHONY: helm-chart
helm-chart: ## Build Helm chart
	@mkdir -p build
	helm package -d build/ vault

.PHONY: check
check: test lint ## Run checks (tests and linters)

.PHONY: test-acceptance
test-acceptance: ## Run acceptance tests
	go test -race -v -timeout 900s -tags kubeall ./test

.PHONY: lint
lint: lint-helm lint-yaml
lint: ## Run linters

.PHONY: lint-helm
lint-helm:
	helm lint vault

.PHONY: lint-yaml
lint-yaml:
	yamllint $(if ${CI},-f github,) --no-warnings .

.PHONY: generate
generate: generate-helm-docs
generate: ## Run generation jobs

.PHONY: generate-helm-docs
generate-helm-docs:
	helm-docs -s file -c . -t README.md.gotmpl

deps: bin/kind bin/helm-docs
deps: ## Install dependencies

bin/kind:
	@mkdir -p bin
	curl -Lo bin/kind https://kind.sigs.k8s.io/dl/v${KIND_VERSION}/kind-$(shell uname -s | tr '[:upper:]' '[:lower:]')-$(shell uname -m | sed -e "s/aarch64/arm64/; s/x86_64/amd64/")
	@chmod +x bin/kind

bin/helm-docs:
	@mkdir -p bin
	curl -L https://github.com/norwoodj/helm-docs/releases/download/v${HELM_DOCS_VERSION}/helm-docs_${HELM_DOCS_VERSION}_$(shell uname)_x86_64.tar.gz | tar -zOxf - helm-docs > ./bin/helm-docs
	@chmod +x bin/helm-docs

.PHONY: help
.DEFAULT_GOAL := help
help:
	@grep -h -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-10s\033[0m %s\n", $$1, $$2}'

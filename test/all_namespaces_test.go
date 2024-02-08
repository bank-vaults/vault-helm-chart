// Copyright © 2019 Banzai Cloud
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//go:build kubeall || helm
// +build kubeall helm

// Fire up a local Kubernetes cluster (`kind create cluster --config test/kind.yaml`)
// and run the test against it (`go test -v -tags kubeall ./test`)

package test

import (
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
)

var (
	vaultVersion      = "latest"
	bankVaultsVersion = "1.20.0"
)

// Installing the operator helm chart before testing
func TestMain(m *testing.M) {
	// Setting Vault version
	vaultVersionEnv, ok := os.LookupEnv("VAULT_VERSION")
	if ok {
		vaultVersion = vaultVersionEnv
	}

	// Run tests
	exitCode := m.Run()

	// Exit based on the test results
	os.Exit(exitCode)
}

func TestVaultHelmChartAllNamespaces(t *testing.T) {
	releaseName := "vault"
	kubectlOptions := k8s.NewKubectlOptions("", "", "default")

	// Set caNamespaces and other configurations to "*"
	os.Setenv("CA_NAMESPACES", "*")
	os.Setenv("BOUND_SA_NAMES", "*")
	os.Setenv("BOUND_SA_NAMESPACES", "*")

	// Setup the args for helm.
	options := &helm.Options{
		KubectlOptions: kubectlOptions,
		SetValues: map[string]string{
			"unsealer.image.tag": bankVaultsVersion,
			"unsealer.args[0]":   "--mode",
			"unsealer.args[1]":   "k8s",
			"unsealer.args[2]":   "--k8s-secret-namespace",
			"unsealer.args[3]":   kubectlOptions.Namespace,
			"unsealer.args[4]":   "--k8s-secret-name",
			"unsealer.args[5]":   "bank-vaults",
			"ingress.enabled":    "true",
			"ingress.hosts[0]":   "localhost",
			"image.tag":          vaultVersion,
		},
	}

	chart := "../vault/"
	if v := os.Getenv("HELM_CHART"); v != "" {
		chart = v
	}

	// Deploy the chart using `helm install`
	helm.Install(t, options, chart, releaseName)
	defer helm.Delete(t, options, releaseName, true)

	// Wait for the Vault pods to be up and running
	k8s.WaitUntilPodAvailable(t, kubectlOptions, "vault-0", 5, 10*time.Second)

	// Get the TLS secret
	k8s.GetSecret(t, kubectlOptions, "vault-tls")

	os.Unsetenv("CA_NAMESPACES")
	os.Unsetenv("BOUND_SA_NAMES")
	os.Unsetenv("BOUND_SA_NAMESPACES")
}

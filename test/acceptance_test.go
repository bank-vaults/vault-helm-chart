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

// Fire up a local Kubernetes cluster (`kind create cluster --config test/kind.yaml`)
// and run the acceptance tests against it (`go test -v -tags kubeall ./test`)

package test

import (
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
)

var (
	vaultVersion      = "latest"
	bankVaultsVersion = "v1.33.1"
)

// Installing the operator helm chart before testing
func TestMain(m *testing.M) {
	// Setting Vault version
	if os.Getenv("VAULT_VERSION") != "" {
		vaultVersion = os.Getenv("VAULT_VERSION")
	}

	// Run tests
	exitCode := m.Run()

	// Exit based on the test results
	os.Exit(exitCode)
}

func TestVaultHelmChart(t *testing.T) {
	releaseName := "vault"
	kubectlOptions := k8s.NewKubectlOptions("", "", "default")

	// Setup the args for helm.
	setValues := map[string]string{
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
	}

	// Vault 2.0.0 fails to start with `Error initializing core: Failed to lock memory`
	// inside containers even with IPC_LOCK granted. The regression was fixed in 2.0.1.
	if vaultVersion == "2.0.0" {
		setValues["vault.config.disable_mlock"] = "true"
	}

	options := &helm.Options{
		KubectlOptions: kubectlOptions,
		SetValues:      setValues,
	}

	chart := "../vault/"
	if v := os.Getenv("HELM_CHART"); v != "" {
		chart = v
	}

	// Deploy the chart using `helm install`
	helm.Install(t, options, chart, releaseName)
	t.Cleanup(func() {
		if t.Failed() {
			dumpDiagnostics(t, kubectlOptions, "vault-0")
		}
		helm.Delete(t, options, releaseName, true)
	})

	// Check the Vault pod to be up and running
	k8s.WaitUntilPodAvailable(t, kubectlOptions, "vault-0", 60, 5*time.Second)
}

// dumpDiagnostics writes Kubernetes state to the test log to help debug failures
func dumpDiagnostics(t *testing.T, kubectlOptions *k8s.KubectlOptions, podName string) {
	t.Helper()

	t.Logf("===== diagnostics for pod %q in namespace %q =====", podName, kubectlOptions.Namespace)

	runKubectl(t, kubectlOptions, "events", "get", "events", "--sort-by=.lastTimestamp")
	runKubectl(t, kubectlOptions, "describe pod "+podName, "describe", "pod", podName)

	pod, err := k8s.GetPodE(t, kubectlOptions, podName)
	if err != nil {
		t.Logf("could not fetch pod %q to enumerate containers: %v", podName, err)
		t.Logf("===== end diagnostics =====")
		return
	}

	for _, c := range pod.Spec.InitContainers {
		dumpContainerLogs(t, kubectlOptions, podName, c.Name, true)
	}
	for _, c := range pod.Spec.Containers {
		dumpContainerLogs(t, kubectlOptions, podName, c.Name, false)
	}

	t.Logf("===== end diagnostics =====")
}

func dumpContainerLogs(t *testing.T, kubectlOptions *k8s.KubectlOptions, podName, container string, init bool) {
	t.Helper()

	kind := "container"
	if init {
		kind = "init-container"
	}

	// Current logs.
	runKubectl(t, kubectlOptions,
		fmt.Sprintf("logs %s/%s (%s)", podName, container, kind),
		"logs", podName, "-c", container, "--tail=500",
	)

	// Previous instance — only meaningful if it has restarted. Skipped quietly otherwise.
	runKubectl(t, kubectlOptions,
		fmt.Sprintf("logs %s/%s (%s, previous)", podName, container, kind),
		"logs", podName, "-c", container, "--tail=500", "--previous",
	)
}

func runKubectl(t *testing.T, kubectlOptions *k8s.KubectlOptions, title string, args ...string) {
	t.Helper()
	out, err := k8s.RunKubectlAndGetOutputE(t, kubectlOptions, args...)
	if err != nil {
		t.Logf("----- %s: %v -----\n%s", title, err, out)
		return
	}
	t.Logf("----- %s -----\n%s", title, out)
}

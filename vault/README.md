# vault

A tool for secrets management, encryption as a service, and privileged access management

This directory contains a Kubernetes Helm chart to deploy a [Vault](https://www.vaultproject.io/) server.
For further details on how we are using Vault read this [post](https://banzaicloud.com/blog/oauth2-vault/).

### Requirements

* Kubernetes 1.6+

### Notes

Please note that a backend service for Vault (for example, Consul) must be deployed beforehand and configured with the `vault.config` option.<br>
YAML provided under this option will be converted to JSON for the final Vault `config.json` file.

Please also note that scaling to more than 1 replicas can be made successfully only with a configured HA Storage backend.
By default this chart uses `file` backend which is not HA.

> See the [official docs](https://developer.hashicorp.com/vault/docs/configuration) for more information.

## Installation

To install the chart, use the following:

```bash
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault
```

To install the chart backed with a Consul cluster, use the following:

```bash
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault \
--set vault.config.storage.consul.path="vault" \
--set vault.config.storage.consul.address="myconsul-svc-name:8500"
```

> Consul helm chart configuration is needed to [expose the service ports](https://developer.hashicorp.com/consul/docs/k8s/helm#v-server-exposeservice) and set up [Consul DNS request resolution](https://developer.hashicorp.com/consul/docs/k8s/dns).

Note that we currently only distribute the chart via GitHub OCI registry.

## Using Vault

Once the Vault pod is ready, it can be accessed using `kubectl port-forward`:

```bash
$ kubectl port-forward vault-pod 8200
$ export VAULT_ADDR=http://127.0.0.1:8200
$ vault status
```

## Amazon S3 example

An alternative `values.yaml` example using the Amazon S3 backend can be specified using:

```yaml
vault:
  config:
    storage:
      s3:
        access_key: "AWS-ACCESS-KEY"
        secret_key: "AWS-SECRET-KEY"
        bucket: "AWS-BUCKET"
        region: "AWS-REGION"
```

An alternate example using Amazon custom secrets passed as environment variables to Vault:

```bash
# Create an Kubernetes secret with your AWS credentials
kubectl create secret generic aws \
--from-literal=AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
--from-literal=AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY

# Tell the chart to pass these as env vars to Vault and as a file mount if needed
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault \
--set "vault.customSecrets[0].secretName=aws" \
--set "vault.customSecrets[0].mountPath=/vault/aws"
```

## Google Storage and KMS example

You can set up Vault to use Google KMS for sealing and Google Storage for storing your encrypted secrets. See the usage example below:

```bash
# Create a google secret with your Secret Account Key file in json fromat.
kubectl create secret generic google --from-literal=GOOGLE_APPLICATION_CREDENTIALS=/etc/gcp/service-account.json --from-file=service-account.json=./service-account.json

# Tell the chart to pass these vars to Vault and as a file mount if needed
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault \
--set "vault.customSecrets[0].secretName=google" \
--set "vault.customSecrets[0].mountPath=/etc/gcp" \
--set "vault.config.storage.gcs.bucket=[google-bucket-name]" \
--set "vault.config.seal.gcpckms.project=[google-project-id]" \
--set "vault.config.seal.gcpckms.region=[google-kms-region]" \
--set "vault.config.seal.gcpckms.key_ring=[google-kms-key-ring]" \
--set "vault.config.seal.gcpckms.crypto_key=[google-kms-crypto-key]" \
--set "unsealer.args[0]=--mode" \
--set "unsealer.args[1]=google-cloud-kms-gcs" \
--set "unsealer.args[2]=--google-cloud-kms-key-ring" \
--set "unsealer.args[3]=[google-kms-key-ring]" \
--set "unsealer.args[4]=--google-cloud-kms-crypto-key" \
--set "unsealer.args[5]=[google-kms-crypto-key]" \
--set "unsealer.args[6]=--google-cloud-kms-location" \
--set "unsealer.args[7]=global" \
--set "unsealer.args[8]=--google-cloud-kms-project" \
--set "unsealer.args[9]=[google-project-id]" \
--set "unsealer.args[10]=--google-cloud-storage-bucket" \
--set "unsealer.args[11]=[google-bucket-name]"
```

## Vault HA with MySQL backend

You can set up a HA Vault to use MySQL for storing your encrypted secrets. MySQL supports the HA coordination of Vault, see the [official docs](https://developer.hashicorp.com/vault/docs/configuration/storage/mysql#high-availability-parameters) for more details.

See the complete working Helm example below:

```bash
# Install MySQL first with the official Helm chart, tell to create a user and a database called 'vault':
helm install mysql oci://registry-1.docker.io/bitnamicharts/mysql \
--set auth.username=vault \
--set auth.database=vault

# Install the Vault chart, tell it to use MySQL as the storage backend, also specify where the 'vault' user's password should be coming from (the MySQL chart generates a secret called 'mysql' holding the password):
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault \
--set replicaCount=2 \
--set vault.config.storage.mysql.address=mysql:3306 \
--set vault.config.storage.mysql.username=vault \
--set vault.config.storage.mysql.password="[[.Env.MYSQL_PASSWORD]]" \
--set "vault.envSecrets[0].secretName=mysql" \
--set "vault.envSecrets[0].secretKey=mysql-password" \
--set "vault.envSecrets[0].envName=MYSQL_PASSWORD"
```

## Values

The following table lists the configurable parameters of the Helm chart.

| Parameter | Type | Default | Description |
| --- | ---- | ------- | ----------- |
| `global.openshift` | bool | `false` | Specify if the chart is being deployed to OpenShift |
| `replicaCount` | int | `1` | Number of replicas |
| `strategy.type` | string | `"RollingUpdate"` | Update strategy to use for Vault StatefulSet |
| `image.repository` | string | `"hashicorp/vault"` | Container image repo that contains HashiCorp Vault |
| `image.tag` | string | `"1.14.8"` | Container image tag |
| `image.pullPolicy` | string | `"IfNotPresent"` | Container image pull policy |
| `service.name` | string | `"vault"` | Vault service name |
| `service.type` | string | `"ClusterIP"` | Vault service type |
| `service.port` | int | `8200` | Vault service external port |
| `service.loadBalancerIP` | string | `nil` | Force Vault load balancer IP |
| `service.annotations` | object | `{}` | Vault service annotations. For example, use `cloud.google.com/load-balancer-type: "Internal"` to specify GCP load balancer type. |
| `headlessService.enabled` | bool | `false` | Enable headless service for Vault |
| `headlessService.name` | string | `"vault"` | Vault headless service name |
| `headlessService.port` | int | `8200` | Vault headless service external port |
| `headlessService.annotations` | object | `{}` | Vault headless service annotations. For example, use `external-dns.alpha.kubernetes.io/hostname: vault.mydomain.com` to create record-set. |
| `ingress.enabled` | bool | `false` | Enable Vault ingress |
| `ingress.ingressClassName` | string | `""` | Vault ingress class name. For Kubernetes >= 1.18, you should specify the ingress-controller via this field. Check: https://kubernetes.io/blog/2020/04/02/improvements-to-the-ingress-api-in-kubernetes-1.18/#specifying-the-class-of-an-ingress |
| `ingress.annotations` | object | `{}` | Vault ingress annotations |
| `ingress.hosts` | list | `[]` | Vault ingress accepted hostnames with path. Used to create Ingress record and should be used with `service.type: ClusterIP`. |
| `ingress.tls` | list | `[]` | Vault ingress TLS configuration. TLS secrets must be manually created in the namespace. |
| `persistence.enabled` | bool | `false` | Enable persistence using Persistent Volume Claims. Check: http://kubernetes.io/docs/user-guide/persistent-volumes/ |
| `persistence.storageClass` | string | `nil` | Set Vault data Persistent Volume Storage Class. If defined, sets the actual `storageClassName: <storageClass>`. If set to "-", sets the actual `storageClassName: ""`, which disables dynamic provisioning. If undefined (the default) or set to null, no `storageClassName` spec is set, choosing the default provisioner.  (gp2 on AWS, standard on GKE, AWS & OpenStack). |
| `persistence.hostPath` | string | `""` | Used for hostPath persistence if PVC is disabled. If both PVC and hostPath persistence are disabled, "emptyDir" will be used. Check: https://kubernetes.io/docs/concepts/storage/volumes/#hostpath |
| `persistence.size` | string | `"10G"` | Set default PVC size |
| `persistence.accessMode` | string | `"ReadWriteOnce"` | Set default PVC access mode. Check: https://kubernetes.io/docs/concepts/storage/persistent-volumes/#access-modes |
| `extraInitContainers` | list | `[]` | Containers to run before the Vault containers are started (init containers) |
| `extraContainers` | list | `[]` | Containers to run alongside Vault containers (sidecar containers) |
| `extraContainerVolumes` | list | `[]` | Extra volume definitions for sidecar and init containers |
| `tls.secretName` | string | `""` | Specify a secret which holds your custom TLS certificate. If not specified, Helm will generate one for you. |
| `tls.caNamespaces` | list | `[]` | Distribute the generated CA certificate Secret to other namespaces |
| `vault.customSecrets` | list | `[]` | Custom secrets available to Vault. Allows the mounting of various custom secrets to enable production Vault configurations. The two fields required are `secretName` indicating the name of the Kubernetes secret (created outside of this chart), and `mountPath` at which it should be mounted in the Vault container. |
| `vault.envSecrets` | list | `[]` | Custom secrets available to Vault as env vars. Allows creating various custom environment variables from secrets to enable production Vault configurations. The three fields required are `secretName` indicating the name of the Kubernetes secret (created outside of this chart), `secretKey` in this secret and `envName` which will be the name of the env var in the containers. |
| `vault.envs` | list | `[]` | Custom env vars available to Vault. |
| `vault.config` | object | `{}` | A YAML representation of the final Vault config file. Check: https://developer.hashicorp.com/vault/docs/configuration |
| `vault.externalConfig` | object | `{}` | A YAML representation of dynamic config data used by Bank-Vaults. Bank-Vaults will use this data to continuously configure Vault. Check: https://bank-vaults.dev/docs/external-configuration/ |
| `unsealer.image.repository` | string | `"ghcr.io/bank-vaults/bank-vaults"` | Container image repo that contains Bank-Vaults |
| `unsealer.image.tag` | string | `"v1.31.1"` | Container image tag |
| `unsealer.image.pullPolicy` | string | `"IfNotPresent"` | Container image pull policy |
| `statsd.image.repository` | string | `"prom/statsd-exporter"` | Container image repo that contains StatsD Prometheus exporter |
| `statsd.image.tag` | string | `"latest"` | Container image tag |
| `statsd.image.pullPolicy` | string | `"IfNotPresent"` | Container image pull policy |
| `rbac.psp.enabled` | bool | `false` | Use pod security policy |
| `serviceAccount.create` | bool | `true` | Specifies whether a service account should be created |
| `serviceAccount.name` | string | `""` | The name of the service account to use. If not set and `create` is true, a name is generated using the fullname template. |
| `serviceAccount.annotations` | object | `{}` | Annotations to add to the service account. For example, use `iam.gke.io/gcp-service-account: gsa@project.iam.gserviceaccount.com` to enable GKE workload identity. |
| `serviceAccount.createClusterRoleBinding` | bool | `true` | Bind `system:auth-delegator` ClusterRoleBinding to this service account |
| `serviceAccount.secretCleanupImage` | object | `{"pullPolicy":"IfNotPresent","repository":"rancher/hyperkube","tag":"v1.30.2-rancher1"}` | secret-cleanup Job image |
| `serviceAccount.secretCleanupImage.repository` | string | `"rancher/hyperkube"` | secret-cleanup Job image repo that contains StatsD Prometheus exporter |
| `serviceAccount.secretCleanupImage.tag` | string | `"v1.30.2-rancher1"` | secret-cleanup Job image tag |
| `serviceAccount.secretCleanupImage.pullPolicy` | string | `"IfNotPresent"` | secret-cleanup Job image pull policy |
| `certManager` | object | `{}` | Configure CertManager issuer and certificate. If enabled, please see necessary changes to `vault.config.listener.tcp` above. Either `issuerRef` must be set to your Issuer or issuer must be enabled to generate a SelfSigned one. |
| `podDisruptionBudget.enabled` | bool | `true` | Enables PodDisruptionBudget |
| `podDisruptionBudget.maxUnavailable` | int | `1` | Represents the number of Pods that can be unavailable (integer or percentage) |
| `podAnnotations` | object | `{}` | Extra annotations to add to pod metadata |
| `labels` | object | `{}` | Additional labels to be applied to the Vault StatefulSet and Pods |
| `resources` | object | `{}` | Resources to request for Vault |
| `nodeSelector` | object | `{}` | Node labels for pod assignment. Check: https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector |
| `tolerations` | list | `[]` | List of node tolerations for the pods. Check: https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/ |
| `affinity` | object | `{}` |  |
| `priorityClassName` | string | `""` | Assign a PriorityClassName to pods if set. Check: https://kubernetes.io/docs/concepts/scheduling-eviction/pod-priority-preemption/ |
| `kubeVersion` | string | `""` | Override cluster version |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`.

## OpenShift Implementation

Tested with
* OpenShift Container Platform 3.11
* Helm 3

First create a new project named "vault"
```bash
oc new-project vault
```
Then create a new `scc` based on the `scc` restricted and add the capability "IPC_LOCK". Now add the new scc to the ServiceAccount vault of the new vault project:
```bash
oc adm policy add-scc-to-user <new_scc> system:serviceaccount:vault:vault
```

Or you can define users in `scc` directly and in this case, you only have to create the `scc`.
```bash
oc create -f <scc_file.yaml>
```

Example vault-restricted `scc` with defined user:
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: vault-restricted
  annotations:
    kubernetes.io/description: This is the least privileged SCC and it is used by vault users.
allowHostIPC: true
allowHostDirVolumePlugin: false
allowHostNetwork: false
allowHostPID: false
allowHostPorts: false
allowPrivilegeEscalation: true
allowPrivilegedContainer: false
defaultAddCapabilities: null
allowedCapabilities:
- IPC_LOCK
allowedUnsafeSysctls: null
fsGroup:
  type: RunAsAny
priority: null
readOnlyRootFilesystem: false
requiredDropCapabilities:
- KILL
- MKNOD
runAsUser:
  type: RunAsAny
seLinuxContext:
  type: MustRunAs
supplementalGroups:
  type: RunAsAny
volumes:
- configMap
- downwardAPI
- emptyDir
- persistentVolumeClaim
- projected
- secret
users:
- system:serviceaccount:default:vault
```

You will get the message, that the user `system:serviceaccount:vault:vault` doesn't exist, but that's ok.
In the next step you install the helm chart vault in the namespace "vault" with the following command:

```bash
helm install vault oci://ghcr.io/bank-vaults/helm-charts/vault \
--set "unsealer.args[0]=--mode" \
--set "unsealer.args[1]=k8s" \
--set "unsealer.args[2]=--k8s-secret-namespace" \
--set "unsealer.args[3]=vault" \
--set "unsealer.args[4]=--k8s-secret-name" \
--set "unsealer.args[5]=bank-vaults"
```

Changing the values of the arguments of the unsealer is necessary because in the `values.yaml` the default namespace is used to store the secret.
Creating the secret in the same namespace like vault is the easiest solution. In alternative you can create a role which allows creating and read secrets in the default namespace.

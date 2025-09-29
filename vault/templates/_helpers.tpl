{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "vault.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified vault name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "vault.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- printf .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "vault.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Overrideable version for container image tags.
*/}}
{{- define "vault.bank-vaults.version" -}}
{{- .Values.unsealer.image.tag -}}
{{- end -}}

{{/*
Create the name of the service account to use
*/}}
{{- define "vault.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "vault.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Return the target Kubernetes version.
https://github.com/bitnami/charts/blob/master/bitnami/common/templates/_capabilities.tpl
*/}}
{{- define "vault.capabilities.kubeVersion" -}}
{{- default .Capabilities.KubeVersion.Version .Values.kubeVersion -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for policy.
*/}}
{{- define "vault.capabilities.policy.apiVersion" -}}
{{- if semverCompare "<1.21-0" (include "vault.capabilities.kubeVersion" .) -}}
{{- print "policy/v1beta1" -}}
{{- else -}}
{{- print "policy/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate apiVersion for ingress.
*/}}
{{- define "vault.capabilities.ingress.apiVersion" -}}
{{- if .Values.ingress -}}
{{- if .Values.ingress.apiVersion -}}
{{- .Values.ingress.apiVersion -}}
{{- else if semverCompare "<1.14-0" (include "vault.capabilities.kubeVersion" .) -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "<1.19-0" (include "vault.capabilities.kubeVersion" .) -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1" -}}
{{- end }}
{{- else if semverCompare "<1.14-0" (include "vault.capabilities.kubeVersion" .) -}}
{{- print "extensions/v1beta1" -}}
{{- else if semverCompare "<1.19-0" (include "vault.capabilities.kubeVersion" .) -}}
{{- print "networking.k8s.io/v1beta1" -}}
{{- else -}}
{{- print "networking.k8s.io/v1" -}}
{{- end -}}
{{- end -}}

{{/*
Return the appropriate securityContext for vault container.
This function adapts the security context by adding the IPC_LOCK capability if `vault.config.disable_mlock` is not enabled.
*/}}
{{- define "vault.bank-vaults.containerSecurityContext" -}}
{{- $securityContext := (dict) -}}
{{- if ($securityContext = include "vault.compatibility.renderSecurityContext" (dict "secContext" .Values.containerSecurityContext "context" .) | fromYaml) | empty | not -}}
    {{- $disableMlock := dig "config" "disable_mlock" false (index .Values "vault") | toString -}}
    {{- if eq $disableMlock "false" -}}
        {{- $capabilitiesAdd := dig "capabilities" "add" (list) $securityContext  -}}
        {{- $capabilitiesAdd = append $capabilitiesAdd "IPC_LOCK" | uniq -}}
        {{- $_securityContext := (dict "capabilities" (dict "add" $capabilitiesAdd)) -}}
        {{- $_ := mergeOverwrite $securityContext $_securityContext -}}
    {{- end -}}
{{- end -}}
{{- $securityContext | toYaml -}}
{{- end -}}

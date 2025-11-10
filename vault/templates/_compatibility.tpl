{{/* vim: set filetype=mustache: */}}
{{/* Based and compatible with Bitnami's common library to handle security contexts */}}
{{/*
Return true if the detected platform is Openshift
Usage:
{{- include "vault.compatibility.isOpenshift" . -}}
*/}}
{{- define "vault.compatibility.isOpenshift" -}}
{{- if .Capabilities.APIVersions.Has "security.openshift.io/v1" -}}
{{- true -}}
{{- end -}}
{{- end -}}

{{/*
Render a compatible securityContext depending on the platform. By default it is maintained as it is.
In other platforms like Openshift we remove default user/group values that do not work out of the box with the restricted-v1 SCC.
Usage:
{{- include "vault.compatibility.renderSecurityContext" (dict "secContext" .Values.containerSecurityContext "context" $) -}}
*/}}
{{- define "vault.compatibility.renderSecurityContext" -}}
{{- $adaptedContext := .secContext | default (dict) -}}
{{- $enabled := dig "enabled" false $adaptedContext | toString -}}
{{- /*
If the `global.openshift` value is set to "force" or "true", we adapt the security context to be compatible with Openshift;
If the `global.openshift` value is set to "auto" or not set, we check if the cluster is Openshift and adapt the security context accordingly.
 */ -}}
{{- $globalOpenshift := dig "global" "openshift" "auto" (.context.Values | toYaml | fromYaml) | toString -}}
{{- if eq $globalOpenshift "true" "auto" "false" -}}
  {{- if or (eq $globalOpenshift "force" "true") (and (eq $globalOpenshift "auto") (include "vault.compatibility.isOpenshift" .context)) -}}
    {{/* Remove incompatible user/group values that do not work in Openshift out of the box */}}
    {{- $adaptedContext = omit $adaptedContext "fsGroup" "runAsUser" "runAsGroup" -}}
    {{- if not .secContext.seLinuxOptions -}}
        {{/* If it is an empty object, we remove it from the resulting context because it causes validation issues */}}
        {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
    {{- end -}}
  {{- end -}}
{{- end -}}
{{/* Remove empty seLinuxOptions object if global.compatibility.omitEmptySeLinuxOptions is set to true */}}
{{- $globalCompatibilityOmitSELinux := dig "global" "compatibility" "omitEmptySeLinuxOptions" false (.context.Values | toYaml | fromYaml) | toString -}}
{{- if and (eq $globalCompatibilityOmitSELinux "true") (not .secContext.seLinuxOptions) -}}
  {{- $adaptedContext = omit $adaptedContext "seLinuxOptions" -}}
{{- end -}}
{{/* Remove fields that are disregarded when running the container in privileged mode */}}
{{- if $adaptedContext.privileged -}}
  {{- $adaptedContext = omit $adaptedContext "capabilities" -}}
{{- end -}}
{{- ternary (omit $adaptedContext "enabled") (dict) (eq $enabled "true") | toYaml -}}
{{- end -}}

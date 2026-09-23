{{/*
Checksum of a subset of the ConfigMap keys: `include "redis.checksum" (list $ "redis.conf" "redis.sh")`.
The redis StatefulSet and the Sentinel Deployment each hash only their own keys,
so a change to one side does not restart the other. Restarting both at once is
what left ~90 s without a master (and wiped the cache-only releases) on every
config change: the sentinels came back without memory while the StatefulSet was
killing the real master.
*/}}
{{- define "redis.checksum" -}}
{{- $root := index . 0 -}}
{{- $cm := include (print $root.Template.BasePath "/redis-configmap.yaml") $root | fromYaml -}}
{{- $parts := list -}}
{{- range $key := rest . -}}
{{- $parts = append $parts (index $cm.data $key | default "") -}}
{{- end -}}
{{- $parts | join "\n---\n" | sha256sum -}}
{{- end -}}

{{/*
Pod affinity: `.Values.affinity` (e.g. anti control-plane) plus a podAntiAffinity
by hostname against the pods of the same component.
`include "redis.affinity" (list $ "<app.kubernetes.io/name>" "<hard|soft|''>")`.
*/}}
{{- define "redis.affinity" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- $mode := index . 2 | default "" -}}
{{- $aff := deepCopy ($root.Values.affinity | default dict) -}}
{{- $term := dict "labelSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" $name "app.kubernetes.io/instance" $root.Release.Name)) "topologyKey" "kubernetes.io/hostname" -}}
{{- if eq $mode "hard" -}}
{{- $_ := set $aff "podAntiAffinity" (dict "requiredDuringSchedulingIgnoredDuringExecution" (list $term)) -}}
{{- else if eq $mode "soft" -}}
{{- $_ := set $aff "podAntiAffinity" (dict "preferredDuringSchedulingIgnoredDuringExecution" (list (dict "weight" 100 "podAffinityTerm" $term))) -}}
{{- end -}}
{{- if $aff -}}
affinity:
{{ toYaml $aff | indent 2 }}
{{- end -}}
{{- end -}}

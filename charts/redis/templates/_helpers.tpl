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
by hostname against the pods of the same component and, optionally, a softer
one against the pods of another component.
`include "redis.affinity" (list $ "<app.kubernetes.io/name>" "<hard|soft|''>" ["<other name>"])`.
The optional fourth item only applies with `podAntiAffinity.separateRedisAndSentinel`:
a drain that takes the master and a sentinel at once is the hard case for a
failover (see sentinel.sh). Only the sentinels carry it: the scheduler also
scores the preferred terms of the pods already on a node, so a redis pod avoids
a sentinel's node too, and the StatefulSet does not roll for it.
*/}}
{{- define "redis.affinity" -}}
{{- $root := index . 0 -}}
{{- $name := index . 1 -}}
{{- $mode := index . 2 | default "" -}}
{{- $other := "" -}}
{{- if gt (len .) 3 -}}{{- $other = index . 3 | default "" -}}{{- end -}}
{{- $aff := deepCopy ($root.Values.affinity | default dict) -}}
{{- $sel := dict "app.kubernetes.io/name" $name "app.kubernetes.io/instance" $root.Release.Name -}}
{{- $term := dict "labelSelector" (dict "matchLabels" $sel) "topologyKey" "kubernetes.io/hostname" -}}
{{- $paa := dict -}}
{{- $preferred := list -}}
{{- if eq $mode "hard" -}}
{{- $_ := set $paa "requiredDuringSchedulingIgnoredDuringExecution" (list $term) -}}
{{- else if eq $mode "soft" -}}
{{- $preferred = append $preferred (dict "weight" 100 "podAffinityTerm" $term) -}}
{{- end -}}
{{- if and $other $root.Values.podAntiAffinity.separateRedisAndSentinel -}}
{{- $otherTerm := dict "labelSelector" (dict "matchLabels" (dict "app.kubernetes.io/name" $other "app.kubernetes.io/instance" $root.Release.Name)) "topologyKey" "kubernetes.io/hostname" -}}
{{- $preferred = append $preferred (dict "weight" 50 "podAffinityTerm" $otherTerm) -}}
{{- end -}}
{{- if $preferred -}}
{{- $_ := set $paa "preferredDuringSchedulingIgnoredDuringExecution" $preferred -}}
{{- end -}}
{{- if $paa -}}
{{- $_ := set $aff "podAntiAffinity" $paa -}}
{{- end -}}
{{- if $aff -}}
affinity:
{{ toYaml $aff | indent 2 }}
{{- end -}}
{{- end -}}

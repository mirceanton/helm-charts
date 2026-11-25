{{- define "volsync.name" -}}{{ default .Release.Name .Values.nameOverride }}{{- end -}}

{{/* Deterministic staggered cron: hash(seed) -> minute + hour offset, expanded over `every` */}}
{{- define "volsync.schedule" -}}
{{- if .Values.backup.schedule -}}
{{- .Values.backup.schedule -}}
{{- else -}}
{{- $every := .Values.backup.every | toString | trimSuffix "h" | int -}}
{{- if or (lt $every 1) (gt $every 24) (ne (mod 24 $every) 0) -}}{{- fail "backup.every must be a whole number of hours that divides 24 (1,2,3,4,6,8,12,24)" -}}{{- end -}}
{{- $seed := default (printf "%s/%s" .Release.Namespace .Release.Name) .Values.backup.seed -}}
{{- $n := int (printf "%d" (print "0x" (substr 0 7 (sha256sum $seed)) | int64)) -}}
{{- $minute := mod $n 60 -}}
{{- $offset := mod (div $n 60) $every -}}
{{- $hours := list -}}
{{- range $i := until (div 24 $every | int) -}}{{- $hours = append $hours (add $offset (mul $i $every)) -}}{{- end -}}
{{- printf "%d %s * * *" $minute (join "," $hours) -}}
{{- end -}}
{{- end -}}

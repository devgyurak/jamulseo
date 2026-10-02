#!/usr/bin/env bash
# Cursor 어댑터 — 반패턴 경고 + 편집 후 검사. 경고만 하고 막지 않는다.
h="$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks"; in=$(cat)
printf '%s' "$in" | "$h/guard-antipatterns.sh"; printf '%s' "$in" | "$h/post-edit.sh"
exit 0

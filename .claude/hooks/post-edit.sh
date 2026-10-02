#!/usr/bin/env bash
# Claude Code 어댑터 (PostToolUse) — 반패턴 경고 + rustfmt·clippy·GWT.
# 공통 구현의 "경고 = 1" 을 exit 2 로 바꾼다: PostToolUse 의 exit 2 는 stderr 를 에이전트에게 돌려준다 (편집은 이미 적용됨).
h="$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks"; in=$(cat); rc=0
printf '%s' "$in" | "$h/guard-antipatterns.sh" || rc=2
printf '%s' "$in" | "$h/post-edit.sh" || rc=2
exit "$rc"

#!/usr/bin/env bash
# Cursor beforeShellExecution 어댑터 — 게이트 우회 시도를 경고한다 (차단은 .githooks/ 와 CI).
cmd=$(cat)
case "$cmd" in *"--no-verify"*) echo "⚠ --no-verify 는 모든 검사를 끄고 기록을 남기지 않습니다. 승인 경로가 아닙니다 (.agents/APPROVAL.md)." >&2 ;; esac
case "$cmd" in *"--fail-under"*|*"DUDECT_T_MAX"*) echo "⚠ 임계값은 scripts/_common.sh 에만 있고 사람 승인 사항입니다 (R4)." >&2 ;; esac
exit 0

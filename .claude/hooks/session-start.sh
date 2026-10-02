#!/usr/bin/env bash
# Claude Code 어댑터 — 공통 구현은 scripts/hooks/session-context.sh. SessionStart 의 stdout 이 컨텍스트가 된다.
exec "$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks/session-context.sh"

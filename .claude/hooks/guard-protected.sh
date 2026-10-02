#!/usr/bin/env bash
# Claude Code 어댑터 (PreToolUse) — 공통 구현은 scripts/hooks/guard-protected.sh. exit 2 = 차단.
exec "$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks/guard-protected.sh"

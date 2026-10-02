#!/usr/bin/env bash
# Claude Code 어댑터 (Stop) — 공통 구현은 scripts/hooks/stop-check.sh. "상기 필요 = 1" 을 exit 2 로 (한 번만: stop_hook_active).
"$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks/stop-check.sh" || exit 2

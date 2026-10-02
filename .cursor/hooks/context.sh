#!/usr/bin/env bash
# Cursor 어댑터 — 공통 구현 직접 호출
exec "$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks/session-context.sh"

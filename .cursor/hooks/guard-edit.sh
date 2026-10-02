#!/usr/bin/env bash
# Cursor 어댑터 — 보호 경로 판정. stdin JSON 을 공통 구현에 그대로 넘긴다.
exec "$(dirname "${BASH_SOURCE[0]}")/../../scripts/hooks/guard-protected.sh"

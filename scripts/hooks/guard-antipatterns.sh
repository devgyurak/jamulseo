#!/usr/bin/env bash
# 반패턴 경고 — 공통 구현 진입점. 판정은 antipatterns.py 에 있다.
# 입력: stdin 도구 JSON 또는 <경로> <내용 파일> / 종료: 0 깨끗함, 1 경고 (stderr)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
command -v python3 >/dev/null 2>&1 || exit 0   # 경고 전용이므로 fail-open (차단은 guard-protected 가 한다)
exec python3 "$HERE/antipatterns.py" "$@"

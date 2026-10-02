#!/usr/bin/env bash
# 편집 후 빠른 피드백 — **공통 구현**.
# rustfmt 적용 + 해당 크레이트 clippy + GWT 네이밍
#
# 입력: $1 경로 / 또는 stdin 으로 도구 JSON
# 종료: 0 깨끗함 / 1 경고 있음 (stderr). 차단하지 않는다.
set -uo pipefail
unset CDPATH
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 0

path="${1:-}"
if [ -z "$path" ] && [ ! -t 0 ]; then
  path=$(python3 -c 'import json,sys
try:
    d=json.load(sys.stdin); d=d.get("tool_input",d) if isinstance(d,dict) else {}
    print(d.get("file_path") or d.get("path") or "")
except Exception:
    pass' 2>/dev/null)
fi
case "$path" in *.rs) ;; *) exit 0 ;; esac
[ -f "$path" ] || exit 0

warned=0
rustfmt --edition 2021 "$path" 2>/dev/null || true

crate=$(printf '%s' "$path" | sed -n 's#.*crates/\([^/]*\)/.*#\1#p')
if [ -n "$crate" ] && [ -f Cargo.toml ] && command -v cargo >/dev/null 2>&1; then
  out=$(cargo clippy -q -p "$crate" --all-targets 2>&1 -- -D warnings || true)
  if printf '%s' "$out" | grep -q '^error'; then
    printf 'clippy (%s):\n%s\n' "$crate" "$(printf '%s' "$out" | grep -A4 '^error' | head -40)" >&2
    warned=1
  fi
fi

if grep -q '#\[test\]' "$path" 2>/dev/null; then
  bad=$("$ROOT/scripts/lint-gwt.sh" --file "$path" 2>&1 >/dev/null || true)
  if [ -n "$bad" ]; then
    printf '%s\n' "$bad" >&2
    warned=1
  fi
fi
exit "$warned"

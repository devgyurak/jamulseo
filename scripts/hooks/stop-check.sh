#!/usr/bin/env bash
# 세션 종료 시 확인 — **공통 구현**.
# Rust·하네스 변경이 있었는데 게이트를 안 돌렸으면 한 번 상기시킨다.
#
# 입력: stdin 도구 JSON (선택). stop_hook_active 가 참이면 이미 한 번 상기시킨 것이므로 조용히 끝낸다.
# 종료: 0 / 1 상기 필요 (stderr)
set -uo pipefail
unset CDPATH
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT" || exit 0

if [ ! -t 0 ]; then
  active=$(python3 -c 'import json,sys
try:
    print("1" if json.load(sys.stdin).get("stop_hook_active") is True else "0")
except Exception:
    print("0")' 2>/dev/null)
  [ "$active" = "1" ] && exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
changed=$(git status --porcelain -- '*.rs' 'Cargo.toml' '*/Cargo.toml' 'tests/' 2>/dev/null | head -50)
[ -n "$changed" ] || exit 0

marker="target/.jms-verified"
if [ -f "$marker" ]; then
  newest=0
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    m=$(stat -f %m "$f" 2>/dev/null || stat -c %Y "$f" 2>/dev/null || echo 0)
    [ "$m" -gt "$newest" ] && newest=$m
  done < <(printf '%s\n' "$changed" | awk '{print $NF}')
  verified=$(stat -f %m "$marker" 2>/dev/null || stat -c %Y "$marker" 2>/dev/null || echo 0)
  [ "$newest" -le "$verified" ] && exit 0
fi

n=$(printf '%s\n' "$changed" | wc -l | tr -d ' ')
cat >&2 <<EOS
⚠ Rust·테스트 파일 ${n}개가 변경되었는데 마지막 변경 이후 게이트를 통과하지 않았습니다.

  ./scripts/verify.sh --fast    (게이트 0~6)

돌릴 수 없는 이유가 있으면 (예: M0 워크스페이스 미생성) 그 이유를 보고에 쓰고 끝내세요.
머지 전에는 전체 게이트(CI)와 교차 리뷰(R3)가 필요합니다.
EOS
exit 1

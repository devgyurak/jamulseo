#!/usr/bin/env bash
# 계약 역방향 검사 — 현재 마일스톤 이하의 계약 조항 단계마다 실행되는 검사가 있는가.
#   ./scripts/contract-check.sh [--milestone Mx] [--exit]
#   --exit: 마일스톤 종료 판정 (미연결 단계·낡은 감사도 실패). 없으면 머지 판정 (미연결 단계는 대기)
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need python3
MS="$CURRENT_MILESTONE"; EXIT=()
while [ $# -gt 0 ]; do
  case "$1" in
    --milestone) [ $# -ge 2 ] || die "--milestone 값이 필요합니다"; MS="$2"; shift 2 ;;
    --exit) EXIT=(--exit); shift ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

args=()
tmp=$(mktemp -d "${TMPDIR:-/tmp}/jms-cc.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
if has_workspace && have cargo; then
  # 실행 목록과 #[ignore] 목록. libtest 의 --list 는 무시된 테스트도 나열하므로 따로 빼야 한다.
  if cargo test --locked --workspace -q -- --list --format terse > "$tmp/all" 2>/dev/null \
     && cargo test --locked --workspace -q -- --list --format terse --ignored > "$tmp/ign" 2>/dev/null; then
    args=(--listing "$tmp/all" --ignored "$tmp/ign")
  fi
fi
rc=0
python3 "$ROOT/scripts/contract_check.py" --root "$ROOT" --milestone "$MS" ${EXIT[@]+"${EXIT[@]}"} ${args[@]+"${args[@]}"} || rc=$?
exit "$rc"

#!/usr/bin/env bash
# 결함 주입 — cargo-mutants. 살아남은 뮤턴트(missed)가 면제 목록 밖에 0 이어야 한다.
#   ./scripts/mutants.sh [--milestone Mx] [--diff-base <ref>] [--only <파일>]
#
#   --diff-base 가 있으면 그 기준과의 diff 에 걸친 뮤턴트만 (PR 용, cargo-mutants --in-diff).
#   없으면 대상 크레이트 전체 (마일스톤 종료 용).
#   면제: tests/mutants/exempt.toml (사람만 고친다 — 사유와 승인자 필수)
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_workspace || die "워크스페이스가 없습니다."
have cargo-mutants || die "cargo-mutants 가 없습니다 — ./scripts/bootstrap.sh"

MS="$CURRENT_MILESTONE"; ONLY=""; BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --milestone) MS="$2"; shift 2 ;;
    --only) ONLY="$2"; shift 2 ;;
    --diff-base) BASE="$2"; shift 2 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done

targets="jamulsoe-core"
ms_ge "$MS" M2 && targets="$targets jamulsoe-module"
ms_ge "$MS" M3 && targets="$targets jamulsoe-ffi"

diff_args=()
if [ -n "$BASE" ]; then
  mkdir -p target/mutants
  git diff "$BASE"...HEAD > target/mutants/pr.diff || die "diff 를 만들 수 없습니다: $BASE"
  diff_args=(--in-diff target/mutants/pr.diff)
  info "증분 모드: $BASE 이후 변경에 걸친 뮤턴트만 (전체는 마일스톤 종료 때)"
fi

for c in $targets; do
  has_crate "$c" || { fail "$c 가 없습니다"; continue; }
  step "cargo mutants -p $c ${ONLY:+--file $ONLY} ${BASE:+--in-diff}"
  out="target/mutants/$c"; rm -rf "$out" "target/mutants/$c.log"; mkdir -p "$out"   # 이전 결과로 판정하지 않도록
  args=(--package "$c" --output "$out" --no-shuffle ${diff_args[@]+"${diff_args[@]}"})
  [ -n "$ONLY" ] && args+=(--file "$ONLY")
  # 종료 코드 (cargo-mutants book "Exit codes"): 0 전부 잡힘 · 2 살아남음 · 3 시간 초과 — 이 셋만 결과 파일로 판정한다.
  # 1 사용법 · 4 기준 테스트 실패 · 5/6 diff 불일치·무효 · 70 내부 오류 — 실행 실패이므로 통과로 세지 않는다.
  rc=0; cargo mutants ${args[@]+"${args[@]}"} > "target/mutants/$c.log" 2>&1 || rc=$?
  case "$rc" in
    0|2|3) ;;
    *) fail "$c: cargo-mutants 실행 실패 (종료 코드 $rc) — target/mutants/$c.log"; continue ;;
  esac
  if [ ! -f "$out/mutants.out/outcomes.json" ]; then
    if [ -n "$BASE" ] && [ "$rc" = 0 ]; then ok "$c: diff 에 걸친 뮤턴트 없음 (종료 코드 0)"; continue; fi
    fail "$c: 결과 파일이 없습니다 (종료 코드 $rc) — 실행 실패를 통과로 세지 않습니다"; continue
  fi
  if python3 "$ROOT/scripts/mutants_judge.py" --crate "$c" --out "$out/mutants.out" \
       --exempt "$ROOT/tests/mutants/exempt.toml" ${BASE:+--incremental}; then
    ok "$c"
  else
    fail "$c: 살아남은 뮤턴트 — 테스트를 강화하세요 (구현이 아니라). 관측 불가능한 변이라면 사유를 정리해 사람에게 면제를 요청하세요"
  fi
done
finish

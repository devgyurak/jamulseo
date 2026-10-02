#!/usr/bin/env bash
# ④ VERIFY — 게이트. 다섯 도구 공통의 "진짜 게이트"다. 도구별 훅은 빠른 피드백일 뿐이다.
# .agents/WORKFLOW.md §④
#
#   ./scripts/verify.sh                  전체 (현재 마일스톤)
#   ./scripts/verify.sh --fast           0~6 (개발 중, pre-push)
#   ./scripts/verify.sh --only 7,9       특정 게이트
#   ./scripts/verify.sh --milestone M1   그 마일스톤의 **종료 조건**으로 판정 (뮤테이션 전체, dudect 기준 장비 포함)
#
# 환경: JMS_REQUIRE_ALL=1 (CI·종료 판정) — "실행 불가"도 실패
#       JMS_DIFF_BASE=<ref> — 뮤테이션 증분 기준 (없으면 origin/main 과의 merge-base, 그것도 없으면 전체)
#       JMS_CT_BASELINE_HOST=1 — 이 장비가 dudect 기준 장비임을 선언 (ct.sh 가 CPU 모델로 다시 확인)
#
# 판정 상태: 통과 / 실패 / 미적용(마일스톤 이전) / 실행 불가(검증 대상 환경 아님)
# JMS_REQUIRE_ALL=1 (CI) 이면 "실행 불가"도 실패다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

MODE=full; ONLY=""; MS="$CURRENT_MILESTONE"; MS_EXIT=0
while [ $# -gt 0 ]; do
  case "$1" in
    --fast) MODE=fast; shift ;;
    --full) MODE=full; shift ;;
    --only) [ $# -ge 2 ] && [ -n "$2" ] || die "--only 값이 필요합니다"; ONLY="$2"; shift 2 ;;
    --milestone) [ $# -ge 2 ] || die "--milestone 값이 필요합니다"; MS="$2"; MS_EXIT=1; shift 2 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done
case "$MS" in M0|M1|M2|M3|M4|M5|M6) ;; *) die "알 수 없는 마일스톤: $MS" ;; esac
if [ -n "$ONLY" ]; then
  case "$ONLY" in ,*|*,|*,,*) die "잘못된 게이트 목록: $ONLY" ;; esac
  IFS=',' read -r -a sel <<< "$ONLY"
  for g in ${sel[@]+"${sel[@]}"}; do
    case "$g" in 0|0b|1|2|3|4|5|6|7|8|9|10|11|11b|12|13|14) ;; *) die "알 수 없는 게이트: $g" ;; esac
  done
fi

REQUIRE_ALL="${JMS_REQUIRE_ALL:-0}"
NA=0; UNAVAIL=0

selected() { [ -z "$ONLY" ] || case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac; }

# gate <번호> <이름> <요구 마일스톤> <조건: any|ws|target> <명령...>
#   any    어디서나
#   ws     Cargo 워크스페이스가 있어야 한다. 없으면 --fast 에서는 미적용, 전체 판정에서는 실패
#          (M0 초기에 워크플로 커밋을 push 할 수 있게 하되, 머지·마일스톤 판정에서는 통과로 세지 않는다)
#   target 검증 대상 환경(Linux x86_64)에서만 판정
#   ct-host dudect 기준 장비에서만 판정 (JMS_CT_BASELINE_HOST=1 + Linux x86_64)
gate() {
  local num="$1" name="$2" since="$3" plat="$4"; shift 4
  selected "$num" || return 0
  printf '\n%s━━━ 게이트 %-3s %s%s\n' "$B" "$num" "$name" "$N"
  if ! ms_ge "$MS" "$since"; then
    printf '%s    미적용 — %s 부터 (통과 판정 아님)%s\n' "$D" "$since" "$N"; NA=$((NA+1)); return 0
  fi
  if [ "$plat" = ws ] && ! has_workspace; then
    if [ "$MODE" = fast ]; then
      printf '%s    미적용 — 워크스페이스(Cargo.toml) 없음. 머지·마일스톤 판정에서는 실패입니다%s\n' "$Y" "$N"; NA=$((NA+1))
    else
      printf '%s    실패 — 워크스페이스(Cargo.toml) 없음 (M0 체크리스트)%s\n' "$R" "$N"; FAILURES=$((FAILURES+1))
    fi
    return 0
  fi
  if { [ "$plat" = target ] && ! is_target_platform; } || { [ "$plat" = ct-host ] && { ! is_target_platform || [ "${JMS_CT_BASELINE_HOST:-0}" != 1 ]; }; }; then
    if [ "$REQUIRE_ALL" = 1 ]; then
      printf '%s    실패 — 검증 대상 환경(Linux x86_64)이 아니라 판정할 수 없음 (JMS_REQUIRE_ALL=1)%s\n' "$R" "$N"
      FAILURES=$((FAILURES+1))
    else
      printf '%s    실행 불가 — Linux x86_64 에서만 판정 (통과 아님, CI 가 판정)%s\n' "$Y" "$N"; UNAVAIL=$((UNAVAIL+1))
    fi
    return 0
  fi
  if "$@"; then printf '%s    게이트 %s 통과%s\n' "$G" "$num" "$N"
  else printf '%s    게이트 %s 실패%s\n' "$R" "$num" "$N"; FAILURES=$((FAILURES+1)); fi
}

printf '%s╔═══════════════════════════════════════════════╗%s\n' "$B" "$N"
printf '%s║  jamulsoe 검증 게이트  mode=%-5s  %-2s         ║%s\n' "$B" "$MODE" "$MS" "$N"
printf '%s╚═══════════════════════════════════════════════╝%s\n' "$B" "$N"
is_target_platform || info "이 환경($(uname -s)/$(uname -m))은 검증 대상이 아닙니다 — 일부 게이트는 '실행 불가'"

# ── 0: 게이트 자체를 먼저 시험한다 ───────────────────────────────
gate 0  "게이트 자기 시험"   M0 any "$ROOT/scripts/selftest-gates.sh"
gate 0b "어댑터 정합성"      M0 any "$ROOT/scripts/check-adapters.sh"

# ── 1~6: 빠른 게이트 ─────────────────────────────────────────────
gate 1 "포맷"               M0 ws  cargo fmt --all -- --check
gate 2 "clippy"             M0 ws  cargo clippy --locked --workspace --all-targets -- -D warnings
gate 3 "GWT 네이밍"          M0 any "$ROOT/scripts/lint-gwt.sh"
gate 4 "assert 존재"         M0 any "$ROOT/scripts/lint-tests.sh"
gate 5 "경계 규약"           M0 ws  "$ROOT/scripts/lint-boundary.sh"
gate 6 "단위·통합·정답 벡터" M0 ws  "$ROOT/scripts/test.sh"

if [ "$MODE" = fast ]; then
  printf '\n%s--fast: 게이트 7~14 생략. 머지 판정이 아닙니다.%s\n' "$Y" "$N"
else
  # ── 7~14: 전체 게이트 ──────────────────────────────────────────
  gate 7  "커버리지 ${COVERAGE_MIN}/${COVERAGE_CORE_MIN}" M1 ws "$ROOT/scripts/coverage.sh"
  if [ "$MS_EXIT" = 1 ]; then
    gate 8 "계약 역방향 (종료 판정)" M0 any "$ROOT/scripts/contract-check.sh" --milestone "$MS" --exit
  else
    gate 8 "계약 역방향 (머지 판정)" M0 any "$ROOT/scripts/contract-check.sh" --milestone "$MS"
  fi
  diff_base=""
  if [ "$MS_EXIT" = 0 ]; then
    diff_base="${JMS_DIFF_BASE:-$(git merge-base HEAD origin/main 2>/dev/null || true)}"
  fi
  gate 9  "뮤테이션${diff_base:+ (증분)}" M1 ws "$ROOT/scripts/mutants.sh" --milestone "$MS" ${diff_base:+--diff-base "$diff_base"}
  gate 10 "Miri + ASan"       M3 target "$ROOT/scripts/memsafety.sh"
  gate 11 "상수 시간 (ctgrind)" M1 target "$ROOT/scripts/ct.sh" --ctgrind --milestone "$MS"
  if [ "$MS_EXIT" = 1 ]; then
    gate 11b "상수 시간 통계 (dudect, 기준 장비)" M1 ct-host "$ROOT/scripts/ct.sh" --dudect --milestone "$MS"
  elif selected 11b; then
    printf '\n%s━━━ 게이트 11b 상수 시간 통계 (dudect)%s\n%s    미적용 — 마일스톤 종료 판정(--milestone)에서만, 기준 장비에서%s\n' "$B" "$N" "$D" "$N"; NA=$((NA+1))
  fi
  gate 12 "ABI·심볼"          M3 target "$ROOT/scripts/abi-check.sh"
  gate 13 "퍼징 스모크"        M3 target "$ROOT/scripts/fuzz.sh"
  gate 14 "재현 빌드"          M4 target "$ROOT/scripts/repro.sh"
fi

printf '\n%s━━━ 요약%s  실패 %d · 미적용 %d · 실행 불가 %d\n' "$B" "$N" "$FAILURES" "$NA" "$UNAVAIL"
if [ "$UNAVAIL" -gt 0 ] || [ "$MODE" = fast ]; then
  printf '%s  이 결과는 머지 판정이 아닙니다. CI(JMS_REQUIRE_ALL=1, ubuntu-24.04)가 판정합니다.%s\n' "$Y" "$N"
fi

if [ "$MODE" = full ] && [ -z "$ONLY" ]; then
  printf '\n%s━━━ 사람이 확인할 것%s\n' "$Y" "$N"
  printf '  □ 구현한 에이전트와 다른 에이전트가 리뷰했는가 (R3) — 비밀값 경로면 ct-auditor 포함\n'
  printf '  □ 리뷰 [P1] 0건, [P2] 해소 또는 이슈+기한\n'
  printf '  □ 커밋이 규약을 따르고 Signed-off-by 가 있는가 (docs/COMMIT.md)\n'
  printf '  □ PR 본문에 "깨뜨릴 수 있는 계약과 그것을 막는 테스트" 가 있는가\n'
  printf '  □ 외부 자료를 참고했다면 docs/provenance.md 에 기록했는가 (R9)\n'
  printf '  □ 보호 경로 변경이 있다면 사람 승인을 받았는가 (R4)\n'
fi

# stop-check.sh 가 "변경 후 게이트를 돌렸는가"를 판단하는 표식. 실패가 없을 때만 남긴다.
# --only 로 일부만 돌린 것은 표식을 남기지 않는다.
if [ "$FAILURES" -eq 0 ] && [ -z "$ONLY" ]; then mkdir -p "$ROOT/target" && : > "$ROOT/target/.jms-verified"; fi
finish

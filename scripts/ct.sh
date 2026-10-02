#!/usr/bin/env bash
# 상수 시간 검사 (C1). 증명이 아니라 회귀 탐지다.
#
#   ./scripts/ct.sh --ctgrind                  C1-07: Valgrind 비밀값 표시. 결정적 — CI 차단 게이트 (verify 게이트 11)
#   ./scripts/ct.sh --dudect [--audit-out F]   C1-08: 통계 검사. **기준 장비에서만** — 마일스톤 종료 조건 (게이트 11b)
#   ./scripts/ct.sh --asm <함수 경로>           C1-09: 릴리스 어셈블리 덤프 (ct-auditor 용, 판정 아님)
#   공통: [--target <이름>]
#
# 하네스 인터페이스 (.agents/rules/harness.md): jamulsoe-ct 의 바이너리 두 개
#   ctgrind [--target T] [--via-so <libjamulsoe.so>]
#   dudect  [--target T] [--via-so <libjamulsoe.so>] --max-t <값> --measurements <N>
# M3 부터는 --via-so 로 **검증 바이너리 자체**를 거치는 대상을 반드시 포함한다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo

MODE=""; TARGET=""; ASM=""; AUDIT_OUT=""; MS="$CURRENT_MILESTONE"
while [ $# -gt 0 ]; do
  case "$1" in
    --ctgrind) MODE=ctgrind; shift ;;
    --dudect) MODE=dudect; shift ;;
    --asm) MODE=asm; ASM="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    --audit-out) AUDIT_OUT="$2"; shift 2 ;;
    --milestone) MS="$2"; shift 2 ;;
    *) die "알 수 없는 옵션: $1" ;;
  esac
done
[ -n "$MODE" ] || die "--ctgrind | --dudect | --asm 중 하나를 고르세요"

baseline() {  # baseline <섹션> <키>
  python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb")).get(sys.argv[2],{}).get(sys.argv[3],""))' \
    "$ROOT/build/baseline.toml" "$1" "$2" 2>/dev/null
}

if [ "$MODE" = asm ]; then
  have cargo-asm || die "cargo-show-asm 이 없습니다 — ./scripts/bootstrap.sh"
  mkdir -p target/ct-asm
  outf="target/ct-asm/$(printf '%s' "$ASM" | tr ':/' '__').s"
  cargo asm --release -p jamulsoe-core --target "$TARGET_TRIPLE" "$ASM" > "$outf" || die "어셈블리 덤프 실패: $ASM"
  ok "덤프: $outf"
  info "조건 분기(jcc), 비밀값 주소의 메모리 접근, div/idiv, 사라진 write_volatile 을 확인하세요"
  info "감사 결과는 docs/audits/ 에 새 파일로 (docs/audits/README.md 형식)"
  exit 0
fi

is_target_platform || die "상수 시간 검사는 검증 대상 환경(Linux x86_64)에서만 의미가 있습니다."
has_crate jamulsoe-ct || die "jamulsoe-ct 하네스가 없습니다 — 통과로 세지 않습니다 (M0/M1 체크리스트)"

step "빌드 (release, 기준 프로파일)"
cargo build --locked --release -p jamulsoe-ct --bins || die "jamulsoe-ct 빌드 실패"
targs=(); [ -n "$TARGET" ] && targs=(--target "$TARGET")
if ms_ge "$MS" M3; then
  cargo build --locked --release -p jamulsoe-ffi || die "libjamulsoe.so 빌드 실패"
  so="$ROOT/target/release/libjamulsoe.so"
  [ -f "$so" ] || die "libjamulsoe.so 가 없습니다"
  targs+=(--via-so "$so")
  info "M3+: 검증 바이너리($so)를 거치는 대상 포함"
fi
bin=target/release

if [ "$MODE" = ctgrind ]; then
  step "ctgrind (Valgrind 비밀값 표시)"
  need valgrind
  [ -x "$bin/ctgrind" ] || die "ctgrind 바이너리가 없습니다"
  valgrind -q --error-exitcode=1 --track-origins=yes "$bin/ctgrind" ${targs[@]+"${targs[@]}"} \
    && ok "ctgrind 통과" || fail "ctgrind: 비밀값 의존 분기·주소 감지 — /jms-ct --asm 으로 확인"
  finish
fi

# ── dudect: 기준 장비에서만 ────────────────────────────────────────
want=$(baseline cpu ct_host_model)
have=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ //')
[ -n "$want" ] || die "기준선 미정: build/baseline.toml [cpu].ct_host_model — 사람이 정합니다"
[ "$want" = "$have" ] || die "기준 장비가 아닙니다 (기준: $want / 현재: $have). 공유 러너의 dudect 결과는 증거가 아닙니다."

step "dudect (t 절댓값 ≤ ${DUDECT_T_MAX}, 측정 ${DUDECT_MEASUREMENTS}) — 한 번 실행, 재실행으로 통과시키지 않음"
[ -x "$bin/dudect" ] || die "dudect 바이너리가 없습니다"
log=$(mktemp "${TMPDIR:-/tmp}/jms-dudect.XXXXXX")
if "$bin/dudect" ${targs[@]+"${targs[@]}"} --max-t "$DUDECT_T_MAX" --measurements "$DUDECT_MEASUREMENTS" | tee "$log"; then
  ok "dudect 통과 (이 측정에서 누출을 못 찾음)"; verdict=pass
else
  fail "dudect: 누출 의심 — 원인을 찾으세요. 재실행해서 통과시키지 않습니다"; verdict=fail
fi
if [ -n "$AUDIT_OUT" ]; then
  case "$AUDIT_OUT" in docs/audits/attested/*) ;; *) die "C1-08 기록은 사람 전용 경로 docs/audits/attested/ 에 둡니다 (레지스트리 attest: human)" ;; esac
  [ -e "$AUDIT_OUT" ] && die "$AUDIT_OUT 이 이미 있습니다 (감사 기록은 새 파일로)"
  mkdir -p "$(dirname "$AUDIT_OUT")"
  {
    printf -- '---\ncontract: C1-08\ntoolchain: %s\ncommit: %s\nscope: crates/jamulsoe-core/src crates/jamulsoe-module/src crates/jamulsoe-ffi/src build/baseline.toml\n' \
      "$(baseline toolchain rust)" "$(git rev-parse HEAD)"
    printf 'target: %s cpu=%s host=%s\nauditor: scripts/ct.sh --dudect\nverdict: %s\n---\n\n' \
      "$TARGET_TRIPLE" "$(baseline cpu target_cpu)" "$have" "$verdict"
    printf '# dudect 기록 (%s)\n\n```\n' "$(date -u +%Y-%m-%dT%H:%MZ)"; cat "$log"; printf '```\n'
  } > "$AUDIT_OUT"
  ok "감사 기록: $AUDIT_OUT"
fi
rm -f "$log"
finish

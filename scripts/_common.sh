#!/usr/bin/env bash
# 모든 스크립트가 공유하는 설정과 헬퍼. 단독 실행하지 않는다.
# 이 파일은 보호 경로다 — 임계값·마일스톤 변경은 사람 승인 (AGENTS.md R4).
set -euo pipefail
unset CDPATH   # 설정돼 있으면 cd 가 경로를 stdout 에 찍어 파이프(tar 등)를 오염시킨다

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# 현재 마일스톤. docs/ROADMAP-STATUS.md 와 함께 바꾼다.
CURRENT_MILESTONE=M0

# ── 경계 ─────────────────────────────────────────────────────────────
BOUNDARY_CRATES="jamulsoe-core jamulsoe-module jamulsoe-ffi"
HARNESS_CRATES="jamulsoe-oracle jamulsoe-ct"

# ── 임계값 (변경은 사람 승인) ────────────────────────────────────────
COVERAGE_MIN=90                                   # 워크스페이스 (하네스 제외)
COVERAGE_CORE_MIN=95                              # 아래 크레이트
COVERAGE_CORE_CRATES="jamulsoe-core jamulsoe-module"
DUDECT_T_MAX=4.5                                  # |t| 가 이것을 넘으면 누출 의심
DUDECT_MEASUREMENTS=1000000                       # 대상당 측정 수
FUZZ_SECONDS=60                                   # 타깃당 스모크 시간

# ── 검증 대상 환경 ───────────────────────────────────────────────────
TARGET_TRIPLE=x86_64-unknown-linux-gnu

# 기준선 CPU 플래그 (build/baseline.toml [cpu].target_cpu, C5-10).
# RUSTFLAGS 환경변수는 .cargo/config.toml 의 [target.*].rustflags 를 **대체**한다. 그래서 RUSTFLAGS 를 직접 쓰는
# 스크립트는 반드시 이것을 앞에 붙인다 — 안 그러면 재현 빌드·감사가 기준선과 다른 플래그로 돈다 (selftest 가 검사).
BASE_RUSTFLAGS=$(python3 -c 'import sys,tomllib
v=str(tomllib.load(open(sys.argv[1],"rb")).get("cpu",{}).get("target_cpu","")).strip()
print(f"-C target-cpu={v}" if v else "")' "$ROOT/build/baseline.toml" 2>/dev/null || true)
# 기준선 nightly (Miri·ASan·cargo-fuzz). "+nightly" 는 고정되지 않은 채널이라 쓰지 않는다 (selftest 가 검사).
BASE_NIGHTLY=$(python3 -c 'import sys,tomllib; print(str(tomllib.load(open(sys.argv[1],"rb")).get("toolchain",{}).get("nightly","")).strip())' "$ROOT/build/baseline.toml" 2>/dev/null || true)
need_base_nightly() { [ -n "$BASE_NIGHTLY" ] || die "기준선 미정: build/baseline.toml [toolchain].nightly"; }
need_base_rustflags() { [ -n "$BASE_RUSTFLAGS" ] || die "기준선 미정: build/baseline.toml [cpu].target_cpu — RUSTFLAGS 를 기준선 없이 쓰지 않습니다"; }

# ── 출력 ─────────────────────────────────────────────────────────────
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
  R=$'\033[31m'; G=$'\033[32m'; Y=$'\033[33m'; B=$'\033[34m'; D=$'\033[2m'; N=$'\033[0m'
else
  R=; G=; Y=; B=; D=; N=
fi

FAILURES=0
step()  { printf '\n%s▶ %s%s\n' "$B" "$*" "$N"; }
ok()    { printf '%s  ✓%s %s\n' "$G" "$N" "$*"; }
warn()  { printf '%s  ▲%s %s\n' "$Y" "$N" "$*"; }
fail()  { printf '%s  ✗%s %s\n' "$R" "$N" "$*"; FAILURES=$((FAILURES+1)); }
info()  { printf '%s    %s%s\n' "$D" "$*" "$N"; }
die()   { printf '\n%s✗ %s%s\n' "$R" "$*" "$N" >&2; exit 1; }

finish() {
  if [ "$FAILURES" -gt 0 ]; then
    printf '\n%s✗ %d개 실패%s\n' "$R" "$FAILURES" "$N"
    printf '%s  임계값을 낮추거나 테스트를 고쳐서 통과시키지 마세요 (AGENTS.md R4, R5).%s\n' "$D" "$N"
    exit 1
  fi
  printf '\n%s✓ 전부 통과%s\n' "$G" "$N"
}

have() { command -v "$1" >/dev/null 2>&1; }
need() { have "$1" || die "$1 이(가) 없습니다. ./scripts/bootstrap.sh 를 실행하세요."; }

# 마일스톤 비교: ms_ge M2 M1 → 참
ms_num() { printf '%s' "${1#M}"; }
ms_ge()  { [ "$(ms_num "$1")" -ge "$(ms_num "$2")" ]; }

# 검증 대상 환경(Linux x86_64)인가
is_target_platform() { [ "$(uname -s)" = Linux ] && [ "$(uname -m)" = x86_64 ]; }

# 워크스페이스가 있는가 (M0 초기에는 없을 수 있다)
has_workspace() { [ -f "$ROOT/Cargo.toml" ]; }

# 크레이트가 있는가
has_crate() { [ -f "$ROOT/crates/$1/Cargo.toml" ]; }

# Rust 소스 (target 제외)
rust_sources() {
  find crates tests fuzz tools -name '*.rs' -type f 2>/dev/null | grep -v '/target/' || true
}

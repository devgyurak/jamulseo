#!/usr/bin/env bash
# 커버리지 — 워크스페이스(하네스 제외) COVERAGE_MIN, core·module COVERAGE_CORE_MIN.
# 임계값은 _common.sh 에만 있다. 낮추지 않는다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_workspace || die "워크스페이스가 없습니다."
have cargo-llvm-cov || die "cargo-llvm-cov 가 없습니다 — ./scripts/bootstrap.sh"

excl=()
for h in $HARNESS_CRATES; do has_crate "$h" && excl+=(--exclude "$h"); done

step "워크스페이스 라인 커버리지 ≥ ${COVERAGE_MIN}%"
if cargo llvm-cov --locked --workspace ${excl[@]+"${excl[@]}"} --fail-under-lines "$COVERAGE_MIN" --summary-only; then
  ok "워크스페이스"
else
  fail "워크스페이스 커버리지 미달"
fi

for c in $COVERAGE_CORE_CRATES; do
  has_crate "$c" || { fail "$c 가 없습니다"; continue; }
  step "$c 라인 커버리지 ≥ ${COVERAGE_CORE_MIN}%"
  if cargo llvm-cov --locked -p "$c" --fail-under-lines "$COVERAGE_CORE_MIN" --summary-only; then ok "$c"
  else fail "$c 커버리지 미달 — 테스트를 추가하세요 (임계값 하향 금지)"; fi
done
finish

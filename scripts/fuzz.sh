#!/usr/bin/env bash
# 퍼징 스모크 — fuzz/fuzz_targets/ 의 타깃마다 FUZZ_SECONDS 초.
# 크래시가 나면 재현 입력을 tests/negative/ 에 **즉시** 고정하고 고친다 (입력을 버리지 않는다).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
have cargo-fuzz || die "cargo-fuzz 가 없습니다 — ./scripts/bootstrap.sh"
[ -d fuzz/fuzz_targets ] || die "fuzz/fuzz_targets 가 없습니다 (M3 필수)"

n=0
for t in fuzz/fuzz_targets/*.rs; do
  [ -f "$t" ] || continue
  name=$(basename "$t" .rs); n=$((n+1))
  step "fuzz $name (${FUZZ_SECONDS}s)"
  if cargo +nightly fuzz run "$name" -- -max_total_time="$FUZZ_SECONDS" >/dev/null 2>&1; then
    ok "$name"
  else
    fail "$name: 크래시 — fuzz/artifacts/$name/ 의 입력을 tests/negative/ 에 고정하세요"
  fi
done
[ "$n" -gt 0 ] || fail "퍼징 타깃이 0개입니다"
finish

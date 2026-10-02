#!/usr/bin/env bash
# 단위·통합·정답 벡터 테스트. 테스트 0개는 실패다 (아무것도 검증하지 않은 것을 통과로 세지 않는다).
#   ./scripts/test.sh [크레이트]
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_workspace || die "워크스페이스(Cargo.toml)가 없습니다."

scope=(--workspace)
[ -n "${1:-}" ] && scope=(-p "$1")

step "테스트 목록"
count=$(cargo test --locked ${scope[@]+"${scope[@]}"} -q -- --list --format terse 2>/dev/null | grep -c ': test$' || true)
if [ "${count:-0}" -eq 0 ]; then
  fail "테스트가 0개입니다 — 실패로 봅니다"
  finish
fi
ok "테스트 ${count}개"

step "실행"
if have cargo-nextest; then
  cargo nextest run --locked ${scope[@]+"${scope[@]}"} --no-fail-fast && ok "nextest 통과" || fail "테스트 실패"
  # nextest 는 doctest 를 돌리지 않는다
  cargo test --locked ${scope[@]+"${scope[@]}"} --doc -q >/dev/null 2>&1 || fail "doctest 실패"
else
  cargo test --locked ${scope[@]+"${scope[@]}"} --no-fail-fast && ok "cargo test 통과" || fail "테스트 실패"
fi
finish

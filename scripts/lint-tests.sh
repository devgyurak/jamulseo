#!/usr/bin/env bash
# assert 없는 테스트 — 커버리지만 올리는 테스트를 잡는다.
# 본문에 assert*!/prop_assert*!/panic 기대(#[should_panic])/헬퍼 호출(check_*/expect_*/verify_*) 이 하나도 없으면 위반.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

files=()
while IFS= read -r f; do files+=("$f"); done < <(rust_sources)
[ "${#files[@]}" -gt 0 ] || { ok "Rust 소스 없음"; exit 0; }

bad=$(awk '
  function flush() {
    if (inbody && !asserted) print FILENAME ":" start ": " name
    inbody=0; asserted=0; depth=0
  }
  FNR==1 { flush(); pending=0; should_panic=0 }
  /^[[:space:]]*#\[should_panic/ { should_panic=1 }
  /^[[:space:]]*#\[(test|tokio::test|proptest)\]/ { pending=1; next }
  pending && match($0, /fn[[:space:]]+[A-Za-z_][A-Za-z0-9_]*/) {
    name = substr($0, RSTART+3, RLENGTH-3); gsub(/^[[:space:]]+/, "", name)
    start=FNR; inbody=1; asserted=should_panic; depth=0; pending=0; should_panic=0
  }
  inbody {
    if ($0 ~ /(assert|assert_eq|assert_ne|prop_assert|prop_assert_eq|debug_assert)!|(check|expect|verify|assert)_[a-z0-9_]*\(/) asserted=1
    o=gsub(/\{/, "{"); c=gsub(/\}/, "}"); depth += o - c
    if (depth <= 0 && (o > 0 || c > 0)) flush()
  }
  END { flush() }' ${files[@]+"${files[@]}"})

if [ -n "$bad" ]; then
  printf 'assert 없는 테스트:\n%s\n테스트는 관측 가능한 결과를 확인해야 합니다 (docs/TESTING.md).\n' "$bad" >&2
  exit 1
fi
ok "모든 테스트에 검증문이 있음"

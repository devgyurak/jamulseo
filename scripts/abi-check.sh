#!/usr/bin/env bash
# ABI·심볼 회귀 (I5) — cbindgen 헤더 diff, nm -D ↔ exports.txt, C 예제 빌드·실행.
# Linux x86_64 전용 (ELF). exports.txt·헤더를 맞춰 고쳐서 통과시키지 않는다 (보호 경로).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_crate jamulsoe-ffi || die "jamulsoe-ffi 가 없습니다."
[ -f exports.txt ] || die "exports.txt 가 없습니다 (사람이 G1 에서 만든다)"
[ -f include/jamulsoe.h ] || die "include/jamulsoe.h 가 없습니다 (사람이 G1 에서 만든다)"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/jms-abi.XXXXXX"); trap 'rm -rf "$tmp"' EXIT

step "헤더 = cbindgen 생성 결과"
need cbindgen
if cbindgen --quiet --crate jamulsoe-ffi --output "$tmp/jamulsoe.h" crates/jamulsoe-ffi 2>"$tmp/cbindgen.err"; then
  if diff -u include/jamulsoe.h "$tmp/jamulsoe.h" > "$tmp/h.diff"; then ok "헤더 일치"
  else fail "헤더가 생성 결과와 다릅니다 — 공개 인터페이스 변경 (사람 승인 필요)"; sed 's/^/      /' "$tmp/h.diff" | head -40; fi
else
  fail "cbindgen 실패"; sed 's/^/      /' "$tmp/cbindgen.err" | head -20
fi

step "export 심볼 = exports.txt"
cargo build --locked --release -p jamulsoe-ffi >/dev/null || die "릴리스 빌드 실패"
so=target/release/libjamulsoe.so
[ -f "$so" ] || so=$(ls target/release/libjamulsoe*.so 2>/dev/null | head -1)
[ -n "$so" ] && [ -f "$so" ] || die "libjamulsoe.so 가 없습니다 (crate-type cdylib, lib name 확인)"
nm -D --defined-only "$so" | awk '$2 ~ /^[TDBRW]$/ {print $3}' | sort -u > "$tmp/actual"
grep -vE '^\s*(#|$)' exports.txt | sed 's/[[:space:]]*$//' | sort -u > "$tmp/expected"
if diff -u "$tmp/expected" "$tmp/actual" > "$tmp/sym.diff"; then
  ok "심볼 $(wc -l < "$tmp/actual" | tr -d ' ')개 일치"
else
  fail "export 심볼이 exports.txt 와 다릅니다 (+ 새로 나감 / - 사라짐)"
  sed 's/^/      /' "$tmp/sym.diff" | tail -n +3 | head -40
fi

step "C 예제 (tests/c/)"
if ls tests/c/*.c >/dev/null 2>&1; then
  for src in tests/c/*.c; do
    b="$tmp/$(basename "$src" .c)"
    cc -std=c11 -Wall -Werror -Iinclude "$src" -L"$(dirname "$so")" -ljamulsoe -Wl,-rpath,"$PWD/$(dirname "$so")" -o "$b" \
      && "$b" && ok "$(basename "$src")" || fail "$(basename "$src")"
  done
else
  fail "tests/c/ 에 C 예제가 없습니다 (M3 필수)"
fi
finish

#!/usr/bin/env bash
# 메모리 안전 — Miri (jamulsoe-ffi 단위 테스트) + C 하네스 AddressSanitizer.
# Linux x86_64 전용 (verify.sh 게이트 10).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_crate jamulsoe-ffi || die "jamulsoe-ffi 가 없습니다."

step "Miri — jamulsoe-ffi"
if cargo +nightly miri --version >/dev/null 2>&1; then
  cargo +nightly miri test -p jamulsoe-ffi && ok "Miri 통과" || fail "Miri 실패"
else
  fail "nightly miri 가 없습니다 — ./scripts/bootstrap.sh"
fi

step "AddressSanitizer — Rust 테스트"
if RUSTFLAGS="-Zsanitizer=address" RUSTDOCFLAGS="-Zsanitizer=address" \
   cargo +nightly test -Zbuild-std --target "$TARGET_TRIPLE" -p jamulsoe-ffi --target-dir target/asan; then
  ok "ASan (Rust) 통과"
else
  fail "ASan (Rust) 실패"
fi

step "AddressSanitizer — C 하네스 (tests/c/)"
if [ -d tests/c ] && ls tests/c/*.c >/dev/null 2>&1; then
  RUSTFLAGS="-Zsanitizer=address" cargo +nightly build -Zbuild-std --target "$TARGET_TRIPLE" \
    -p jamulsoe-ffi --target-dir target/asan >/dev/null || { fail "ASan 빌드 실패"; finish; }
  lib="target/asan/$TARGET_TRIPLE/debug"
  for src in tests/c/*.c; do
    bin="target/asan/$(basename "$src" .c)"
    cc -fsanitize=address -g -Iinclude "$src" -L"$lib" -ljamulsoe -Wl,-rpath,"$PWD/$lib" -o "$bin" \
      && "$bin" && ok "$(basename "$src")" || fail "$(basename "$src")"
  done
else
  fail "tests/c/ 에 C 하네스가 없습니다 (M3 필수)"
fi
finish

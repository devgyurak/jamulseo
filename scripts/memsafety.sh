#!/usr/bin/env bash
# 메모리 안전 — Miri (jamulsoe-ffi 단위 테스트) + C 하네스 AddressSanitizer.
# Linux x86_64 전용 (verify.sh 게이트 10).
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
need_base_nightly
has_crate jamulsoe-ffi || die "jamulsoe-ffi 가 없습니다."
need_base_rustflags

step "Miri — jamulsoe-ffi"
if cargo +"$BASE_NIGHTLY" miri --version >/dev/null 2>&1; then
  cargo +"$BASE_NIGHTLY" miri test -p jamulsoe-ffi && ok "Miri 통과" || fail "Miri 실패"
else
  fail "nightly miri 가 없습니다 — ./scripts/bootstrap.sh"
fi

step "AddressSanitizer — Rust 테스트"
if RUSTFLAGS="$BASE_RUSTFLAGS -Zsanitizer=address" RUSTDOCFLAGS="$BASE_RUSTFLAGS -Zsanitizer=address" \
   cargo +"$BASE_NIGHTLY" test -Zbuild-std --target "$TARGET_TRIPLE" -p jamulsoe-ffi --target-dir target/asan; then
  ok "ASan (Rust) 통과"
else
  fail "ASan (Rust) 실패"
fi

step "AddressSanitizer — C 하네스 (tests/c/)"
if [ -d tests/c ] && ls tests/c/*.c >/dev/null 2>&1; then
  RUSTFLAGS="$BASE_RUSTFLAGS -Zsanitizer=address" cargo +"$BASE_NIGHTLY" build -Zbuild-std --target "$TARGET_TRIPLE" \
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

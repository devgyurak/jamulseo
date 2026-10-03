#!/usr/bin/env bash
# 재현 가능한 빌드 (C5-11) — 서로 다른 두 경로에서 릴리스 cdylib 을 빌드해 SHA-256 비교.
# CI 는 서로 다른 두 러너에서 같은 일을 하고, 다이제스트로 고정한 컨테이너를 쓴다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_crate jamulsoe-ffi || die "jamulsoe-ffi 가 없습니다."
is_target_platform || die "검증 대상 바이너리는 Linux x86_64 ELF 입니다."
need_base_rustflags

epoch="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || echo 0)}"
tmp=$(mktemp -d "${TMPDIR:-/tmp}/jms-repro.XXXXXX"); trap 'rm -rf "$tmp"' EXIT

build_in() {  # build_in <디렉터리>
  local dir="$1"
  mkdir -p "$dir"
  git ls-files -z | (cd "$ROOT" && xargs -0 tar cf -) | (cd "$dir" && tar xf -)
  (cd "$dir" && SOURCE_DATE_EPOCH="$epoch" \
     RUSTFLAGS="$BASE_RUSTFLAGS --remap-path-prefix=$dir=/build --remap-path-prefix=${CARGO_HOME:-$HOME/.cargo}=/cargo" \
     cargo build --locked --release -p jamulsoe-ffi --target "$TARGET_TRIPLE" >/dev/null 2>&1) || return 1
  sha256sum "$dir/target/$TARGET_TRIPLE/release/libjamulsoe.so" | awk '{print $1}'
}

step "빌드 A"
a=$(build_in "$tmp/a/src") || die "빌드 A 실패"
info "$a"
step "빌드 B (다른 경로)"
b=$(build_in "$tmp/bb/other/src") || die "빌드 B 실패"
info "$b"

if [ "$a" = "$b" ]; then ok "SHA-256 일치"; else
  fail "SHA-256 불일치 — 비결정 요소를 찾으세요 (diffoscope). 비교를 느슨하게 하지 않습니다"
fi
finish

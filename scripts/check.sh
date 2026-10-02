#!/usr/bin/env bash
# 빠른 피드백 — fmt + clippy + 빌드. 개발 중 자주 돌린다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need cargo
has_workspace || die "워크스페이스(Cargo.toml)가 없습니다."

step "cargo fmt"
if cargo fmt --all -- --check >/dev/null 2>&1; then ok "포맷 정상"; else fail "포맷 위반 — cargo fmt --all"; fi

step "cargo clippy (-D warnings)"
if cargo clippy --locked --workspace --all-targets -- -D warnings; then ok "clippy 통과"
else fail "clippy 위반"; info "#[allow(...)] 로 넘기지 말고 고치세요. 정당한 예외는 이유 주석 필수."; fi

step "빌드"
cargo build --locked --workspace --all-targets >/dev/null && ok "빌드 성공" || fail "빌드 실패"
finish

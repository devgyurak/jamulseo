#!/usr/bin/env bash
# 최초 설정 — 어느 도구를 쓰든 저장소를 처음 열었을 때 한 번 실행.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"

step "필수 전제"
# 보호 경로 판정과 경계 린트가 python3 (tomllib, 3.11+) 을 요구한다.
# 없으면 **모든 편집이 차단된다** (fail-closed). 조용히 넘어가지 않는다.
if have python3 && python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)'; then
  ok "python3 ($(python3 --version 2>&1))"
else
  fail "python3 3.11+ 없음 — 보호 경로 판정이 동작하지 않아 모든 편집이 차단됩니다"
  info "macOS: brew install python@3.12 / Ubuntu 24.04: 기본 python3 은 3.12"
fi

baseline() {  # baseline <섹션> <키> — build/baseline.toml (사람이 정한 기준선)
  python3 -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb")).get(sys.argv[2],{}).get(sys.argv[3],""))' \
    "$ROOT/build/baseline.toml" "$1" "$2" 2>/dev/null
}

step "Rust 툴체인 (rust-toolchain.toml)"
if have rustup; then
  rustup show active-toolchain >/dev/null 2>&1 && ok "rustup ($(rustup show active-toolchain 2>/dev/null | head -1))"
  rustup component add rustfmt clippy llvm-tools-preview >/dev/null 2>&1 || warn "rustfmt/clippy/llvm-tools 설치 실패"
  rustup target add "$TARGET_TRIPLE" >/dev/null 2>&1 || true
  nightly=$(baseline toolchain nightly)
  if [ -z "$nightly" ]; then
    warn "기준선 미정: build/baseline.toml [toolchain].nightly — Miri·ASan·fuzz(게이트 10·13)를 돌릴 수 없습니다"
  elif rustup toolchain install "$nightly" --profile minimal --component miri rust-src >/dev/null 2>&1; then
    ok "$nightly + miri"
  else
    fail "$nightly 설치 실패"
  fi
else
  warn "rustup 없음 — https://rustup.rs"
fi

step "cargo 도구 (버전: build/baseline.toml [tools])"
install_tool() {  # install_tool <실행 이름> <크레이트>
  local want; want=$(baseline tools "$2")
  [ -n "$want" ] || { fail "$2: 기준선에 버전이 없습니다"; return; }
  if have "$1" && cargo install --list 2>/dev/null | grep -q "^$2 v$want:"; then ok "$2 $want"; return; fi
  printf '    설치 중: %s %s\n' "$2" "$want"
  cargo install "$2" --version "$want" --locked >/dev/null 2>&1 && ok "$2 $want 설치됨" || fail "$2 $want 설치 실패"
}
if have cargo; then
  install_tool cargo-nextest   cargo-nextest
  install_tool cargo-llvm-cov  cargo-llvm-cov
  install_tool cargo-mutants   cargo-mutants
  install_tool cargo-fuzz      cargo-fuzz
  install_tool cbindgen        cbindgen
  install_tool cargo-asm       cargo-show-asm
else
  warn "cargo 없음"
fi

step "검증 대상 환경 도구 (Linux x86_64)"
if is_target_platform; then
  for t in valgrind nm cc; do have "$t" && ok "$t" || warn "$t 없음 — apt install valgrind binutils build-essential"; done
else
  warn "$(uname -s)/$(uname -m): 상수 시간·ABI·ASan·재현 빌드 게이트는 이 환경에서 '실행 불가'입니다 (CI 가 판정)"
fi

step "git hooks"
if git rev-parse --git-dir >/dev/null 2>&1; then
  git config core.hooksPath .githooks
  chmod +x .githooks/* 2>/dev/null || true
  ok "core.hooksPath = .githooks"
  info "훅이 없는 도구(codex, pi, cursor 일부)에서도 같은 게이트가 걸립니다"
else
  warn "git 저장소가 아닙니다"
fi

step "실행 권한"
chmod +x scripts/*.sh scripts/hooks/*.sh scripts/hooks/*.py .claude/hooks/*.sh .cursor/hooks/*.sh 2>/dev/null || true
ok "scripts/, 도구 훅"

step "도구별 설정 확인"
check_cfg() { [ -e "$1" ] && ok "$2  ($1)" || warn "$2  ($1 없음)"; }
check_cfg AGENTS.md               "공통 원천"
check_cfg CLAUDE.md               "claude-code"
check_cfg .claude/settings.json   "claude-code 훅"
check_cfg .codex/config.toml      "codex"
check_cfg .pi/config.toml         "pi"
check_cfg .opencode/opencode.json "opencode"
check_cfg .cursor/hooks.json      "cursor"

printf '\n%s준비 완료.%s 다음을 읽고 시작하세요:\n' "$G" "$N"
printf '  1. AGENTS.md              — 절대 규칙 R1~R10\n'
printf '  2. docs/CONTRACTS.md      — 계약 C1~C5, 불변식 I1~I5\n'
printf '  3. .agents/WORKFLOW.md    — 6단계 작업 루프\n'
printf '  4. docs/ROADMAP-STATUS.md — 현재 마일스톤 (%s)\n' "$CURRENT_MILESTONE"
printf '\n  게이트 자기 시험: ./scripts/selftest-gates.sh\n'
printf '  빠른 게이트:     ./scripts/verify.sh --fast\n'
finish

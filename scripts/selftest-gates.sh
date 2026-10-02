#!/usr/bin/env bash
# 게이트 자기 시험 — 게이트가 위반을 **실제로** 잡는가. 게이트가 틀리면 그 뒤의 모든 결과가 무의미하다.
# scripts/hooks/protected.tsv 에 행을 추가하면 여기에도 항목을 추가한다.
#
# 실제 저장소를 건드리지 않는다: 파일이 필요한 경우는 임시 저장소(JMS_GUARD_ROOT, 임시 git)에서 판정한다.
source "$(dirname "${BASH_SOURCE[0]}")/_common.sh"
need python3
GUARD="$ROOT/scripts/hooks/guard-protected.sh"
ANTI="$ROOT/scripts/hooks/guard-antipatterns.sh"
COMMIT_MSG="$ROOT/.githooks/commit-msg"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/jms-selftest.XXXXXX"); trap 'rm -rf "$tmp"' EXIT

expect() {  # expect <기대 종료 코드> <설명> <명령...>
  local want="$1" what="$2"; shift 2
  local got=0
  "$@" >/dev/null 2>"$tmp/err" || got=$?
  if [ "$got" = "$want" ]; then ok "$what"
  else fail "$what — 기대 $want, 실제 $got"; sed 's/^/        /' "$tmp/err" | head -6; fi
}
expect_out() {  # expect_out <기대 종료 코드> <출력에 있어야 할 문구> <설명> <명령...> — 다른 이유로 실패한 것을 통과로 세지 않는다
  local want="$1" pat="$2" what="$3"; shift 3
  local got=0
  "$@" >"$tmp/out" 2>&1 || got=$?
  if [ "$got" = "$want" ] && grep -Fq -- "$pat" "$tmp/out"; then ok "$what"
  else fail "$what — 기대 $want + '$pat', 실제 $got"; grep -E '✗' "$tmp/out" | head -5 | sed 's/^/        /'; fi
}
json_write() { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"content":sys.argv[2]}}))' "$1" "$2"; }
json_edit()  { python3 -c 'import json,sys; print(json.dumps({"tool_input":{"file_path":sys.argv[1],"old_string":sys.argv[2],"new_string":sys.argv[3]}}))' "$1" "$2" "$3"; }
guard_json() { printf '%s' "$1" | "$GUARD"; }
guard_fake() { JMS_GUARD_ROOT="$FAKE" "$GUARD"; }   # stdin 그대로

# ── 0. 스크립트 정적 검사 ──────────────────────────────────────────
step "스크립트 정적 검사"
# macOS 기본 bash 3.2 + set -u 에서 빈 배열 "${a[@]}" 는 unbound 오류가 나고, `cmd || rc=$?` 문맥에서는
# 검사를 건너뛴 채 0 으로 끝났다 (contract-check.sh 가 그렇게 fail-open 했다). ${a[@]+"${a[@]}"} 를 쓴다.
bad_arr=$(grep -nE '(^|[^+])"\$\{[A-Za-z_]+\[@\]\}"' "$ROOT"/scripts/*.sh "$ROOT"/scripts/hooks/*.sh "$ROOT"/.githooks/* 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' || true)
if [ -n "$bad_arr" ]; then fail "빈 배열에 안전하지 않은 펼치기:"; printf '%s\n' "$bad_arr" | sed 's/^/        /'
else ok "빈 배열 펼치기가 bash 3.2 에서 안전"; fi

# ── 1. 보호 경로 — 경로만으로 차단 (human) ─────────────────────────
step "사람 승인 경로 (human)"
for p in docs/PLAN.md docs/CONTRACTS.md docs/contracts.md docs/kcmvp/inquiries.md exports.txt include/jamulsoe.h \
         rust-toolchain.toml build/baseline.toml tests/mutants/exempt.toml AGENTS.md CLAUDE.md .agents/roles/core-engineer.md \
         scripts/verify.sh scripts/ct.sh scripts/new-gate.sh scripts/contract_check.py scripts/hooks/judge.py scripts/hooks/protected.tsv \
         .githooks/pre-commit .github/workflows/ci.yml .github/APPROVERS .claude/settings.json .claude/hooks/post-edit.sh \
         .cursor/hooks.json .cursor/hooks/guard-edit.sh .opencode/opencode.json .opencode/plugin/x.js .codex/config.toml .pi/config.toml \
         .claude/agents/oracle-author.md .codex/agents/oracle-author.toml .opencode/agent/oracle-author.md .claude/commands/jms-ct.md \
         .cursor/rules/000-core.mdc docs/audits/attested/2026-10-02-C1-08-dudect.md; do
  expect 2 "차단: $p" guard_json "$(json_write "$ROOT/$p" "x")"
done
for p in docs/kcmvp/inquiry-drafts.md crates/jamulsoe-core/src/lib.rs docs/provenance.md docs/TESTING.md Cargo.toml; do
  expect 0 "허용: $p" guard_json "$(json_write "$ROOT/$p" "x")"
done

classify() { [ "$(python3 "$ROOT/scripts/hooks/judge.py" --classify "$1")" = "$2" ]; }
expect 0 "분류: ./ 로 시작하는 경로 (./.claude/settings.json → human)" classify ./.claude/settings.json human
expect 0 "분류: ./ 로 시작하는 경로 (./docs/adr/0001.md → adr)"         classify ./docs/adr/0001.md adr

# ── 2. fail-closed ─────────────────────────────────────────────────
step "fail-closed (입력을 해석하지 못하면 차단)"
expect 2 "잘린 JSON"            guard_json '{"tool_input":{"file_path":"docs/CONTR'
expect 2 "최상위가 배열"         guard_json '["docs/CONTRACTS.md"]'
expect 0 "유효한 JSON, 대상 없음" guard_json '{"tool_input":{}}'

# ── 3. 파일이 필요한 경우 — 임시 저장소 ─────────────────────────────
FAKE="$tmp/repo"
mkdir -p "$FAKE/docs/adr" "$FAKE/docs/real" "$FAKE/docs/audits" "$FAKE/tests/vectors" "$FAKE/tests/negative" "$FAKE/tests/contracts"
ADR() {  # ADR <상태> <방향 확인>
  printf '# ADR-0001: 시험\n\n- **상태**: %s\n- **방향 확인**: %s\n- **날짜**: 2026-10-02\n\n---\n\n## 맥락\n본문\n' "$1" "$2"
}
ADR 제안 대기 > "$FAKE/docs/adr/0001-proposed.md"
ADR 채택 "devgyurak 2026-10-03" > "$FAKE/docs/adr/0002-adopted.md"
ADR 기각 "devgyurak 2026-10-03" > "$FAKE/docs/adr/0003-rejected.md"
printf 'COUNT = 0\nKEY = 00\nCT = 11\n' > "$FAKE/tests/vectors/aria.rsp"
printf '| 파일 | 출처 |\n|---|---|\n| aria.rsp | RFC 5794 |\n' > "$FAKE/tests/vectors/SOURCES.md"
printf 'case1\n' > "$FAKE/tests/negative/n.txt"
printf -- '---\ncontract: C4-03\n---\n' > "$FAKE/docs/audits/old.md"
printf 'contract\n' > "$FAKE/docs/CONTRACTS.md"
ln -s ../CONTRACTS.md "$FAKE/docs/real/alias.md"
REG='{"entries":[{"id":"C1-01","stages":[{"milestone":"M1","check":"test","test":["a::t1"]}]},{"id":"C4-03","stages":[{"milestone":"M1","check":"manual","evidence":"","scope":["crates/c/src","build/baseline.toml"],"attest":"human"}]}]}'
printf '%s\n' "$REG" > "$FAKE/tests/contracts/registry.json"
reg_edit() { python3 -c 'import json,sys; d=json.loads(sys.argv[1]); exec(sys.argv[2]); print(json.dumps(d))' "$REG" "$1"; }
RJ="$FAKE/tests/contracts/registry.json"

step "ADR 승인 경계"
expect 0 "새 ADR (제안, 방향 확인 대기)"   guard_fake <<< "$(json_write "$FAKE/docs/adr/0009-new.md" "$(ADR 제안 대기)")"
expect 2 "새 ADR 에 방향 확인을 채움"      guard_fake <<< "$(json_write "$FAKE/docs/adr/0009-new.md" "$(ADR 제안 "누군가 2026-10-02")")"
expect 2 "새 ADR (채택)"                guard_fake <<< "$(json_write "$FAKE/docs/adr/0009-new.md" "$(ADR 채택 대기)")"
expect 0 "제안 ADR 본문 수정"            guard_fake <<< "$(json_edit "$FAKE/docs/adr/0001-proposed.md" "본문" "고친 본문")"
expect 2 "제안 → 채택 (짧은 치환)"       guard_fake <<< "$(json_edit "$FAKE/docs/adr/0001-proposed.md" "제안" "채택")"
expect 2 "제안 → 기각"                  guard_fake <<< "$(json_edit "$FAKE/docs/adr/0001-proposed.md" "제안" "기각")"
expect 2 "방향 확인 채움 (사람만)"        guard_fake <<< "$(json_edit "$FAKE/docs/adr/0001-proposed.md" "대기" "에이전트 2026-10-02")"
expect 2 "방향 확인 줄을 하나 더 덧붙임"     guard_fake <<< "$(json_edit "$FAKE/docs/adr/0001-proposed.md" "- **날짜**" "- **방향 확인**: 에이전트 2026-10-02
- **날짜**")"
expect 2 "채택 ADR 수정"                guard_fake <<< "$(json_edit "$FAKE/docs/adr/0002-adopted.md" "본문" "고친 본문")"
expect 2 "기각 ADR 수정"                guard_fake <<< "$(json_edit "$FAKE/docs/adr/0003-rejected.md" "본문" "고친 본문")"
expect 2 "기각 → 제안 되돌리기"           guard_fake <<< "$(json_edit "$FAKE/docs/adr/0003-rejected.md" "기각" "제안")"
expect 2 "비정규 상태 표기"              guard_fake <<< "$(json_write "$FAKE/docs/adr/0009-new.md" $'# ADR\n\nStatus: 채택\n')"
expect 2 "ADR 삭제"                     env JMS_GUARD_ROOT="$FAKE" JMS_CHANGE=D "$GUARD" "$FAKE/docs/adr/0001-proposed.md"
expect 2 "symlink 경유 계약 수정"         guard_fake <<< "$(json_write "$FAKE/docs/real/alias.md" "x")"

step "추가 전용 (벡터·코퍼스·감사·표준)"
expect 0 "새 벡터 파일"                  guard_fake <<< "$(json_write "$FAKE/tests/vectors/new.rsp" "x")"
expect 2 "벡터 데이터 끝에 붙이기"         guard_fake <<< "$(json_write "$FAKE/tests/vectors/aria.rsp" $'COUNT = 0\nKEY = 00\nCT = 11\nCOUNT = 1\n')"
expect 2 "벡터 레코드 안에 줄 끼워 넣기"    guard_fake <<< "$(json_write "$FAKE/tests/vectors/aria.rsp" $'COUNT = 0\nKEY = 00\nCT = 22\nCT = 11\n')"
expect 0 "SOURCES.md 끝에 행 추가"        guard_fake <<< "$(json_write "$FAKE/tests/vectors/SOURCES.md" $'| 파일 | 출처 |\n|---|---|\n| aria.rsp | RFC 5794 |\n| new.rsp | NIST |\n')"
expect 2 "SOURCES.md 중간에 행 삽입"      guard_fake <<< "$(json_write "$FAKE/tests/vectors/SOURCES.md" $'| 파일 | 출처 |\n|---|---|\n| x | y |\n| aria.rsp | RFC 5794 |\n')"
expect 2 "SOURCES.md 행 수정"            guard_fake <<< "$(json_edit "$FAKE/tests/vectors/SOURCES.md" "RFC 5794" "RFC 9999")"
expect 2 "벡터 파일 삭제"                env JMS_GUARD_ROOT="$FAKE" JMS_CHANGE=D "$GUARD" "$FAKE/tests/vectors/aria.rsp"
expect 2 "코퍼스 수정"                   guard_fake <<< "$(json_edit "$FAKE/tests/negative/n.txt" "case1" "case2")"
expect 0 "새 감사 기록"                  guard_fake <<< "$(json_write "$FAKE/docs/audits/new.md" "x")"
expect 2 "감사 기록 수정"                guard_fake <<< "$(json_edit "$FAKE/docs/audits/old.md" "C4-03" "C4-04")"
expect 0 "새 표준 원문"                  guard_fake <<< "$(json_write "$FAKE/docs/standards/rfc0000.txt" "x")"
printf 'COUNT = 0\nCT = 11\n' > "$tmp/old"; printf 'COUNT = 0\nCT = 22\n' > "$tmp/new"
expect 2 "pre-commit 경로: HEAD 대비 수정" env JMS_GUARD_ROOT="$FAKE" JMS_CHANGE=M JMS_OLD_CONTENT_FILE="$tmp/old" \
  JMS_LOGICAL_PATH=tests/vectors/aria.rsp "$GUARD" tests/vectors/aria.rsp "$tmp/new"

step "계약 레지스트리 판정"
expect 0 "테스트 이름 추가"   guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][0]["stages"][0]["test"].append("a::t2")')")"
expect 0 "새 항목 추가"       guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"].append({"id":"C9-99","stages":[{"milestone":"M2","check":"test","test":[]}]})')")"
expect 0 "evidence 채움"     guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][1]["stages"][0]["evidence"]="docs/audits/x.md"')")"
expect 2 "항목 삭제"          guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"].pop(0)')")"
expect 2 "마일스톤 미루기"     guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][0]["stages"][0]["milestone"]="M4"')")"
expect 2 "test → manual 전환" guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][0]["stages"][0]["check"]="manual"')")"
expect 2 "연결된 테스트 제거"   guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][0]["stages"][0]["test"]=[]')")"
expect 2 "단계 제거"          guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][0]["stages"]=[]')")"
expect 0 "scope 넓히기"        guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][1]["stages"][0]["scope"].append("crates/d/src")')")"
expect 2 "scope 좁히기"        guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'd["entries"][1]["stages"][0]["scope"]=["crates/c/src"]')")"
expect 2 "attest 제거"        guard_fake <<< "$(json_write "$RJ" "$(reg_edit 'del d["entries"][1]["stages"][0]["attest"]')")"
expect 2 "깨진 JSON"          guard_fake <<< "$(json_write "$RJ" '{"entries": [')"

# ── 4. 반패턴 경고 (차단 아님, 경고 = 1) ───────────────────────────
step "반패턴 경고"
anti() { printf '%s' "$(json_write "$ROOT/$1" "$2")" | "$ANTI"; }
expect 1 "core 의 unwrap"            anti crates/jamulsoe-core/src/aria.rs 'let x = y.unwrap();'
expect 1 "core 의 unsafe"            anti crates/jamulsoe-core/src/aria.rs 'unsafe { f() }'
expect 1 "core 의 S-box 테이블 조회"  anti crates/jamulsoe-core/src/aria.rs 'let s = SBOX[x as usize];'
expect 1 "태그 == 비교"               anti crates/jamulsoe-core/src/gcm.rs 'if tag == expected { return Ok(()) }'
expect 1 "ffi 의 Box::new"           anti crates/jamulsoe-ffi/src/lib.rs 'let b = Box::new(ctx);'
expect 1 "ffi 의 SAFETY 없는 unsafe"  anti crates/jamulsoe-ffi/src/lib.rs 'unsafe { *out = p; }'
expect 0 "ffi 의 SAFETY 있는 unsafe"  anti crates/jamulsoe-ffi/src/lib.rs $'// SAFETY: 1~6 단계 통과\nunsafe { *out = p; }'
expect 0 "하네스의 unwrap"            anti crates/jamulsoe-oracle/src/lib.rs 'let x = y.unwrap();'
expect 1 "빌드 설정의 target-cpu=native" anti .cargo/config.toml 'rustflags = ["-C", "target-cpu=native"]'
expect 0 "스크립트 속 문자열은 오탐 아님"   anti scripts/x.py '"target-cpu=native" in text'

# ── 5. 경계 린트 + 기준선 ──────────────────────────────────────────
step "경계 린트 (lint_boundary.py)"
WS="$tmp/ws"
mk_ws() {
  rm -rf "$WS"; mkdir -p "$WS/crates" "$WS/build" "$WS/.cargo"
  printf '[toolchain]\nchannel = "1.98.1"\n' > "$WS/rust-toolchain.toml"
  printf '[toolchain]\nrust = "1.98.1"\ntarget = "x86_64-unknown-linux-gnu"\n[cpu]\ntarget_cpu = "x86-64-v2"\n[profile.release]\npanic = "abort"\nlto = "fat"\ncodegen-units = 1\n' > "$WS/build/baseline.toml"
  printf '[target.x86_64-unknown-linux-gnu]\nrustflags = ["-C", "target-cpu=x86-64-v2"]\n' > "$WS/.cargo/config.toml"
  printf '[workspace]\nmembers = ["crates/*"]\n[profile.release]\npanic = "abort"\nlto = "fat"\ncodegen-units = 1\n' > "$WS/Cargo.toml"
  for c in core module ffi; do mkdir -p "$WS/crates/jamulsoe-$c/src"; done
  printf '#![no_std]\n#![forbid(unsafe_code)]\n' > "$WS/crates/jamulsoe-core/src/lib.rs"
  printf '#![forbid(unsafe_code)]\n' > "$WS/crates/jamulsoe-module/src/lib.rs"
  : > "$WS/crates/jamulsoe-ffi/src/lib.rs"
  printf '[package]\nname = "jamulsoe-core"\n' > "$WS/crates/jamulsoe-core/Cargo.toml"
  printf '[package]\nname = "jamulsoe-module"\n[dependencies]\njamulsoe-core = { path = "../jamulsoe-core" }\n' > "$WS/crates/jamulsoe-module/Cargo.toml"
  printf '[package]\nname = "jamulsoe-ffi"\n[lib]\ncrate-type = ["cdylib"]\n[dependencies]\njamulsoe-module = { path = "../jamulsoe-module" }\n' > "$WS/crates/jamulsoe-ffi/Cargo.toml"
}
lb() { python3 "$ROOT/scripts/lint_boundary.py" --root "$WS" --boundary "$BOUNDARY_CRATES" --harness "$HARNESS_CRATES"; }
sub() { python3 -c 'import sys; p=sys.argv[1]; s=open(p).read(); assert sys.argv[2] in s; open(p,"w").write(s.replace(sys.argv[2],sys.argv[3]))' "$@"; }
mk_ws; expect 0 "정상 워크스페이스" lb
mk_ws; printf '[dev-dependencies]\nproptest = "1"\n' >> "$WS/crates/jamulsoe-core/Cargo.toml"; expect 0 "dev-dependencies 는 허용" lb
mk_ws; printf '[dependencies]\nzeroize = "1"\n' >> "$WS/crates/jamulsoe-core/Cargo.toml"; expect 1 "core 외부 의존" lb
mk_ws; printf 'jamulsoe-core = { path = "../jamulsoe-core" }\n' >> "$WS/crates/jamulsoe-ffi/Cargo.toml"; expect 1 "ffi → core 직접 의존" lb
mk_ws; printf '#![forbid(unsafe_code)]\n' > "$WS/crates/jamulsoe-core/src/lib.rs"; expect 1 "core no_std 누락" lb
mk_ws; sub "$WS/Cargo.toml" 'panic = "abort"' 'panic = "unwind"'; expect 1 "panic = unwind" lb
mk_ws; sub "$WS/Cargo.toml" 'lto = "fat"' 'lto = "thin"'; expect 1 "lto 가 기준선과 다름" lb
mk_ws; sub "$WS/build/baseline.toml" 'lto = "fat"' 'lto = ""'; expect 1 "기준선 미정" lb
mk_ws; sub "$WS/rust-toolchain.toml" '1.98.1' 'stable'; expect 1 "툴체인이 기준선과 다름" lb
mk_ws; sub "$WS/.cargo/config.toml" 'x86-64-v2' 'x86-64-v3'; expect 1 "target-cpu 가 기준선과 다름" lb
mk_ws; sub "$WS/.cargo/config.toml" 'target-cpu=x86-64-v2' 'target-cpu=native'; expect 1 "target-cpu=native" lb
mk_ws; sub "$WS/crates/jamulsoe-ffi/Cargo.toml" '"cdylib"' '"cdylib", "staticlib"'; expect 1 "staticlib" lb
mk_ws; rm -rf "$WS/crates/jamulsoe-ffi"; expect 1 "경계 크레이트 누락" lb

# ── 6. 계약 역방향 검사 ─────────────────────────────────────────────
step "계약 역방향 검사 (contract_check.py — 머지 판정 / 종료 판정)"
CC="$tmp/cc"
mk_cc() {
  rm -rf "$CC"; mkdir -p "$CC/docs/audits/attested" "$CC/tests/contracts" "$CC/scripts" "$CC/crates/c/src"
  printf '| ID | 조항 | 마일스톤 |\n|---|---|---|\n| C1-01 | a | M1 |\n| C4-03 | b | M1 |\n| C5-01 | c | M0 · M1 |\n' > "$CC/docs/CONTRACTS.md"
  printf 'gate 5 x "$ROOT/scripts/lint-boundary.sh"\n' > "$CC/scripts/verify.sh"; : > "$CC/scripts/lint-boundary.sh"
  printf '[toolchain]\nchannel = "1.98.1"\n' > "$CC/rust-toolchain.toml"
  printf 'pub fn f() {}\n' > "$CC/crates/c/src/lib.rs"
  git -C "$CC" init -q && git -C "$CC" -c user.name=t -c user.email=t@e add -A && git -C "$CC" -c user.name=t -c user.email=t@e commit -qm base
  c=$(git -C "$CC" rev-parse HEAD)
  for f in docs/audits/zero.md docs/audits/attested/zero.md; do
    printf -- '---\ncontract: C4-03\ntoolchain: 1.98.1\ncommit: %s\nscope: crates/c/src\nverdict: pass\n---\n' "$c" > "$CC/$f"
  done
  printf 't::given_a_when_b_then_c: test\nt::given_x_when_y_then_z: test\n' > "$CC/all"
  printf 't::given_x_when_y_then_z: test\n' > "$CC/ign"
  cc_reg '"given_a_when_b_then_c"' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src"]' ''
}
cc_reg() {  # cc_reg <C1-01 테스트 목록(JSON 원소)> <C4-03 evidence> <C5-01 마일스톤들> <C4-03 최소 scope(JSON)> <C4-03 attest>
  python3 - "$CC/tests/contracts/registry.json" "$@" <<'PY'
import json, sys
p, tests, ev, ms, scope, attest = sys.argv[1:]
manual = {"milestone": "M1", "check": "manual", "evidence": ev, "scope": json.loads(scope)}
if attest:
    manual["attest"] = attest
d = {"entries": [
  {"id": "C1-01", "stages": [{"milestone": "M1", "check": "test", "test": json.loads("[" + tests + "]")}]},
  {"id": "C4-03", "stages": [manual]},
  {"id": "C5-01", "stages": [{"milestone": m, "check": "gate:lint-boundary"} for m in json.loads("[" + ms + "]")]},
]}
json.dump(d, open(p, "w"))
PY
}
cc()      { python3 "$ROOT/scripts/contract_check.py" --root "$CC" --milestone M1 --listing "$CC/all" --ignored "$CC/ign"; }
cc_exit() { python3 "$ROOT/scripts/contract_check.py" --root "$CC" --milestone M1 --listing "$CC/all" --ignored "$CC/ign" --exit; }
mk_cc; expect 0 "정상 (머지)" cc; expect 0 "정상 (종료)" cc_exit
mk_cc; cc_reg '' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src"]' ''
       expect 0 "미연결 테스트 단계 — 머지 판정은 대기" cc; expect 1 "미연결 테스트 단계 — 종료 판정은 실패" cc_exit
mk_cc; cc_reg '"given_a_when_b_then_c"' '' '"M0","M1"' '["crates/c/src"]' ''
       expect 0 "미연결 감사 단계 — 머지 판정은 대기" cc; expect 1 "미연결 감사 단계 — 종료 판정은 실패" cc_exit
mk_cc; cc_reg '"given_x_when_y_then_z"' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src"]' ''; expect 1 "#[ignore] 테스트 연결 (머지 판정도 실패)" cc
mk_cc; cc_reg '"given_nope_when_x_then_y"' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src"]' ''; expect 1 "없는 테스트 연결 (머지 판정도 실패)" cc
mk_cc; cc_reg '"given_a_when_b_then_c"' 'docs/audits/zero.md' '"M0","M4"' '["crates/c/src"]' ''; expect 1 "마일스톤이 CONTRACTS.md 와 다름" cc
mk_cc; cc_reg '"given_a_when_b_then_c"' 'docs/provenance.md' '"M0","M1"' '["crates/c/src"]' ''; expect 1 "manual evidence 가 감사 파일이 아님" cc
mk_cc; cc_reg '"given_a_when_b_then_c"' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src","build/baseline.toml"]' ''
       expect 1 "감사 scope 가 레지스트리 최소 범위를 덮지 않음" cc
mk_cc; cc_reg '"given_a_when_b_then_c"' 'docs/audits/zero.md' '"M0","M1"' '["crates/c/src"]' 'human'
       expect 1 "attest: human 인데 attested/ 밖의 기록" cc
mk_cc; cc_reg '"given_a_when_b_then_c"' 'docs/audits/attested/zero.md' '"M0","M1"' '["crates/c/src"]' 'human'
       expect 0 "attest: human 이고 attested/ 의 기록" cc
mk_cc; printf 'pub fn g() {}\n' >> "$CC/crates/c/src/lib.rs"; git -C "$CC" -c user.name=t -c user.email=t@e commit -qam change
       expect 0 "감사 뒤 범위 코드 변경 — 머지 판정은 경고" cc; expect 1 "감사 뒤 범위 코드 변경 — 종료 판정은 실패" cc_exit
mk_cc; printf '[toolchain]\nchannel = "1.99.0"\n' > "$CC/rust-toolchain.toml"
       expect 0 "감사 툴체인 ≠ 현재 — 머지 판정은 경고" cc; expect 1 "감사 툴체인 ≠ 현재 — 종료 판정은 실패" cc_exit

# ── 7. 커밋 메시지 ──────────────────────────────────────────────────
step "커밋 메시지 (.githooks/commit-msg)"
GITD="$tmp/git"; mkdir -p "$GITD/scripts/hooks"; git -C "$GITD" init -q
cp "$ROOT/scripts/hooks/judge.py" "$ROOT/scripts/hooks/adr_status.py" "$ROOT/scripts/hooks/protected.tsv" "$GITD/scripts/hooks/"
cm() { printf '%s\n' "$1" > "$tmp/msg"; (cd "$GITD" && "$COMMIT_MSG" "$tmp/msg"); }
SOB="Signed-off-by: tester <tester@example.com>"
expect 0 "정상 ADD"               cm "ADD(core): ARIA 키 스케줄 추가"$'\n\n'"Contracts: C1, C4"$'\n'"$SOB"
expect 1 "Contracts 없음"         cm "ADD(core): ARIA 키 스케줄 추가"$'\n\n'"$SOB"
expect 1 "Signed-off-by 없음"     cm "DOCS: 문서 고침 테스트"$'\n\n'"Contracts: none"
expect 1 "타입 없음"              cm "ARIA 키 스케줄 추가"$'\n\n'"$SOB"
expect 1 "Merge 로 위장"          cm "Merge 아무거나"$'\n\n'"$SOB"
expect 1 "승인자 트레일러 불일치"   env JMS_APPROVED_BY=devgyurak bash -c 'cd "$0" && "$1" "$2"' "$GITD" "$COMMIT_MSG" "$tmp/msg"
printf 'x\n' > "$GITD/AGENTS.md"; printf 'y\n' > "$GITD/lib.rs"; git -C "$GITD" add AGENTS.md lib.rs
expect 1 "사람 승인 경로와 일반 변경 혼합" cm "DOCS: 규약 고침 시험"$'\n\n'"Approved-by: devgyurak"$'\n'"$SOB"
git -C "$GITD" rm -q --cached lib.rs
expect 1 "사람 승인 경로에 Approved-by 없음" cm "DOCS: 규약 고침 시험"$'\n\n'"$SOB"
expect 0 "사람 승인 경로 + Approved-by"     cm "DOCS: 규약 고침 시험"$'\n\n'"Approved-by: devgyurak"$'\n'"$SOB"

# ── 8. 서버 측 판정 (check-protected-diff.sh) ─────────────────────
step "서버 측 판정 — 승인자 목록·서명 (check-protected-diff.sh)"
if have ssh-keygen; then
  CP="$tmp/cp"; mkdir -p "$CP/scripts/hooks" "$CP/.github" "$CP/docs"
  cp "$ROOT/scripts/_common.sh" "$ROOT/scripts/check-protected-diff.sh" "$CP/scripts/"
  cp "$ROOT/scripts/hooks/"{guard-protected.sh,resolve-edit.py,adr_status.py,judge.py,protected.tsv} "$CP/scripts/hooks/"
  ssh-keygen -q -t ed25519 -N '' -C approver -f "$tmp/key" >/dev/null
  ssh-keygen -q -t ed25519 -N '' -C other -f "$tmp/key2" >/dev/null
  printf 'approver\tapprover@example.com\n' > "$CP/.github/APPROVERS"
  printf 'approver@example.com namespaces="git" %s\n' "$(cut -d' ' -f1,2 "$tmp/key.pub")" > "$CP/.github/allowed_signers"
  printf 'contract\n' > "$CP/docs/CONTRACTS.md"
  g() { git -C "$CP" -c user.name=t -c user.email=t@e -c gpg.format=ssh "$@"; }
  g init -q; g add -A; g commit -qm "base" ; base=$(g rev-parse HEAD)
  case_commit() {  # case_commit <브랜치> <메시지> <서명 키|-> — 계약 문서를 고치는 커밋
    g checkout -q -b "$1" "$base"; printf 'changed %s\n' "$1" > "$CP/docs/CONTRACTS.md"; g add -A
    if [ "$3" = - ]; then g commit -qm "$2"; else g -c user.signingkey="$3" commit -q -S -m "$2"; fi
  }
  cpd() { (cd "$CP" && ./scripts/check-protected-diff.sh "$base" "$1"); }
  M="DOCS: 계약 고침"$'\n\n'"Signed-off-by: t <t@e>"
  case_commit unsigned  "$M"$'\n'"Approved-by: approver" -;            expect 1 "승인 트레일러만 있고 서명 없음" cpd unsigned
  case_commit stranger  "$M"$'\n'"Approved-by: stranger" "$tmp/key";  expect 1 "목록에 없는 승인자"          cpd stranger
  case_commit otherkey  "$M"$'\n'"Approved-by: approver" "$tmp/key2"; expect 1 "승인자가 아닌 키로 서명"      cpd otherkey
  case_commit good      "$M"$'\n'"Approved-by: approver" "$tmp/key";  expect 0 "목록의 승인자 + 그 키의 서명"  cpd good
  case_commit nosob     "DOCS: 계약 고침"$'\n\n'"Approved-by: approver" "$tmp/key"; expect 1 "Signed-off-by 없음" cpd nosob
  # 머지 커밋: 승인된 PR(good)을 다른 쪽 줄기에 머지 — 머지 커밋은 서명·승인·DCO 가 없다
  g checkout -q -b mainline "$base"; printf 'x\n' > "$CP/other.txt"; g add -A; g commit -qm "ADD: 다른 변경"$'\n\n'"Signed-off-by: t <t@e>"
  g branch -q mainline-evil
  g merge -q --no-ff good -m "Merge pull request #1 from good"
  expect_out 0 "결과 내용을 만든 승인 커밋" "승인된 PR 의 깨끗한 머지 커밋 (커밋별 + 순 변경)" cpd mainline
  g checkout -q mainline-evil; g merge -q --no-ff --no-commit good
  printf 'evil\n' > "$CP/docs/CONTRACTS.md"; g add -A; g commit -qm "Merge good"$'\n\n'"Signed-off-by: t <t@e>"
  expect 1 "머지 커밋에서 보호 파일을 따로 고침 (evil merge)" cpd mainline-evil

  # 순 변경: 머지로 보호 파일을 옛 버전으로 되돌리기 (커밋별로는 아무것도 걸리지 않는 경우)
  #   main 에서 승인된 커밋이 gate.sh 를 v1 → v2 로 강화 / 그 전에 갈라진 브랜치가 main 을 머지하며 gate.sh 만 v1 로 유지
  cpd3() { (cd "$CP" && ./scripts/check-protected-diff.sh "$1" "$2" "$3"); }
  g checkout -q -b gate-base "$base"; printf 'v1\n' > "$CP/scripts/gate.sh"; g add -A
  g -c user.signingkey="$tmp/key" commit -q -S -m "UPT: 게이트 v1"$'\n\n'"Approved-by: approver"$'\n'"Signed-off-by: t <t@e>"
  gbase=$(g rev-parse HEAD)
  g checkout -q -b stale "$gbase"; printf 'y\n' > "$CP/stale.txt"; g add -A; g commit -qm "ADD: 다른 작업"$'\n\n'"Signed-off-by: t <t@e>"
  g checkout -q -b gate-main "$gbase"; printf 'v2\n' > "$CP/scripts/gate.sh"; g add -A
  g -c user.signingkey="$tmp/key" commit -q -S -m "UPT: 게이트 강화 v2"$'\n\n'"Approved-by: approver"$'\n'"Signed-off-by: t <t@e>"
  gmain=$(g rev-parse HEAD)
  g checkout -q stale; g merge -q --no-ff --no-commit gate-main || true
  g checkout -q "$gbase" -- scripts/gate.sh; g add -A; g commit -qm "Merge branch 'gate-main' into stale"
  g checkout -q -b gate-result "$gmain"; g merge -q --no-ff stale -m "Merge pull request #2 from stale"   # GitHub 의 refs/pull/N/merge 와 같은 것
  expect_out 1 "scripts/gate.sh: 기준 대비 바뀌었는데" "PR: 머지로 승인된 게이트 강화를 되돌림 (순 변경)" cpd3 "$gmain" stale gate-result
  cpd_push() { (cd "$CP" && ./scripts/check-protected-diff.sh "$1" "$2"); }
  expect_out 1 "scripts/gate.sh: 기준 대비 바뀌었는데" "push: 머지 뒤 main 에서 게이트가 옛 버전 (순 변경)" cpd_push "$gmain" gate-result
  g checkout -q -b good-result "$base"; g merge -q --no-ff good -m "Merge pull request #1 from good"
  expect_out 0 "결과 내용을 만든 승인 커밋" "PR: 승인된 커밋이 만든 내용 그대로의 순 변경" cpd3 "$base" good good-result
  expect_out 1 "둘째 부모가 head 가 아닙니다" "PR: 낡은 머지 결과는 거부"                   cpd3 "$base" stale good-result
  # protected.yml 과 같은 방식: merge-tree + commit-tree 로 머지 결과를 직접 계산
  ci_result() { local t; t=$(g merge-tree --write-tree "$1" "$2") || return 1; g commit-tree "$t" -p "$1" -p "$2" -m "test merge"; }
  r_good=$(ci_result "$base" good);   expect_out 0 "결과 내용을 만든 승인 커밋" "CI 계산 머지(merge-tree): 승인된 PR"        cpd3 "$base" good "$r_good"
  r_bad=$(ci_result "$gmain" stale);  expect_out 1 "scripts/gate.sh: 기준 대비 바뀌었는데" "CI 계산 머지(merge-tree): 옛 버전으로 되돌림" cpd3 "$gmain" stale "$r_bad"
else
  fail "ssh-keygen 이 없어 서명 판정을 시험할 수 없습니다"
fi

# ── 9. 뮤테이션 실행 실패 (mutants.sh) ─────────────────────────────
step "뮤테이션 — 실행 실패를 통과로 세지 않음 (mutants.sh)"
MT="$tmp/mt"; mkdir -p "$MT/scripts" "$MT/crates/jamulsoe-core" "$MT/bin"
cp "$ROOT/scripts/_common.sh" "$ROOT/scripts/mutants.sh" "$ROOT/scripts/mutants_judge.py" "$MT/scripts/"
printf '[workspace]\n' > "$MT/Cargo.toml"; printf '[package]\nname = "jamulsoe-core"\n' > "$MT/crates/jamulsoe-core/Cargo.toml"
git -C "$MT" init -q; git -C "$MT" -c user.name=t -c user.email=t@e add -A; git -C "$MT" -c user.name=t -c user.email=t@e commit -qm base
printf '#!/bin/sh\n[ "$1" = mutants ] || exit 0\nexit "${FAKE_MUTANTS_RC:-0}"\n' > "$MT/bin/cargo"; cp "$MT/bin/cargo" "$MT/bin/cargo-mutants"
chmod +x "$MT/bin/"*
mt() { (cd "$MT" && env PATH="$MT/bin:$PATH" FAKE_MUTANTS_RC="$1" ./scripts/mutants.sh "${@:2}"); }
expect 1 "증분: cargo-mutants 기준 테스트 실패(4)"   mt 4 --diff-base HEAD
expect 1 "증분: cargo-mutants 내부 오류(70)"        mt 70 --diff-base HEAD
expect 0 "증분: 종료 코드 0, 결과 없음 = 뮤턴트 없음"  mt 0 --diff-base HEAD
expect 1 "전체: 종료 코드 0 인데 결과 없음"          mt 0

finish

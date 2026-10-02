# CLAUDE.md — Claude Code 어댑터

@AGENTS.md

**규칙은 `AGENTS.md` 와 `.agents/` 에만 있다.** 이 파일에 복제하지 않는다.
Claude Code 전용 운용만 적는다.

## 자동으로 들어오는 것

| 경로 | 시점 |
|---|---|
| `AGENTS.md` | 세션 시작 |
| `.claude/rules/core.md` · `review-commit.md` | 세션 시작 (symlink → `.agents/rules/`) |
| `.claude/rules/*.md` 나머지 | `paths:` 에 맞는 파일을 읽을 때만 |
| `.claude/agents/*.md` 13개 | 서브에이전트 호출 시 |
| `scripts/hooks/session-context.sh` 출력 | `SessionStart` 훅 |

`.claude/` 아래 파일은 `settings.json` 과 `hooks/` 를 빼고 **전부 생성물 또는 symlink**다 (`scripts/sync-agents.sh`).
`settings.json`(훅·권한)과 `hooks/*.sh`(3~5줄 어댑터)는 손으로 관리한다.
생성물을 직접 수정하면 다음 동기화에서 사라지고, `./scripts/check-adapters.sh` 가 드리프트로 잡는다.

## 훅이 하는 일

| 이벤트 | 훅 | 결과 |
|---|---|---|
| `SessionStart` | 현재 마일스톤·계약·G1 대기 질문 주입 | 컨텍스트 |
| `PreToolUse` (Edit·Write·NotebookEdit) | 보호 경로 판정 (`scripts/hooks/protected.tsv`) | **차단** (exit 2) |
| `PostToolUse` (Edit·Write) | 반패턴 경고(C1·C2·C4·R6·R8) + rustfmt·clippy·GWT | 경고를 **Claude 에게 되돌림** (exit 2) |
| `Stop` | Rust 변경 후 게이트 미실행이면 한 번 상기 | 한 번만 (`stop_hook_active`) |

PostToolUse 의 exit 2 는 "편집 실패"가 아니라 **경고 전달**이다. 편집은 이미 적용됐다.
경고가 오탐이면 근거를 대고 넘어가고, 진짜면 고친다.

## 서브에이전트 운용

병렬로 띄울 조합 — 서로를 오염시키지 않도록 **한 메시지에서 동시에**:

```
① 초안 직후   :  spec-redteam                                  (반박할 초안이 있어야 한다)
①′ 반박 뒤    :  멈추고 사람의 방향 확인을 기다린다              (ADR 의 '방향 확인' 필드 — 사람만 채운다)
② 확인 뒤     :  oracle-author  ∥  harness-engineer            (반례가 반영된 명세로 쓴다)
⑤ 구현 직후   :  rust-reviewer  ∥  contract-auditor  [∥ ct-auditor]
                 ct-auditor 는 diff 가 비밀값 경로(core, module 의 키 처리, ffi 의 컨텍스트)를 건드릴 때
```

🚫 `spec-redteam` · `oracle-author` · 리뷰어 · `ct-auditor` 는 **구현·명세 작성 문맥을 가진 에이전트를 재사용하지 않는다.**
처음 띄울 때는 항상 새로 띄운다 (`.agents/INDEPENDENCE.md`).
예외 하나: **[P1] 재확인**은 그 리뷰를 낸 리뷰어를 `SendMessage` 로 이어 쓴다 (`docs/CODE-REVIEW.md §5`).
오라클 작성은 `./scripts/spec-bundle.sh --for oracle-author` 묶음(표준 원문 포함)만 연다.
가능하면 오라클은 **구현과 다른 계열 모델**로 돌린다 — Codex 어댑터(`.codex/agents/oracle-author.toml`)를 쓰면 기억 오류의 상관이 줄어든다.
`ct-auditor` 는 감사 결과를 `docs/audits/` 에 **직접** 새 파일로 남긴다 (구현자가 대신 요약하지 않는다).

## 슬래시 명령

`/jms-*` 12개가 `.agents/workflows/` 로 symlink 되어 있다.
`spec` `harness` `impl` `verify` `review` `commit` `adr` `contract-check` `ct` `abi` `mutants` `repro`

## 운용 팁

- G1 전에는 `crates/jamulsoe-module`·`jamulsoe-ffi` 의 API를 확정하는 작업을 하지 않는다 (`docs/ROADMAP-STATUS.md`)
- 계약·경계·ABI를 건드리는 변경은 plan mode 로 들어간다
- 표준 원문·GVI 해석이 필요한 질문은 웹 검색 결과로 단정하지 않는다. `docs/kcmvp/inquiry-drafts.md` 에 질문 초안으로 남긴다 (R10)
- macOS 에서 `verify.sh --full` 은 일부 게이트가 "실행 불가"다. **머지 판정은 CI(ubuntu-24.04)** 가 한다
- 보호 경로는 훅·권한이 막는다. **셸(`sed -i`, `cat >`)로 우회하지 않는다** — CI(base 의 판정기)가 막고 이력에 남는다
- 게이트가 이상하면 **게이트부터 의심한다**: `./scripts/selftest-gates.sh`. 게이트를 고쳐야 하면 사람에게 요청한다

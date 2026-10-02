# `.agents/` — 에이전트 운영 규약

## 이 디렉터리와 `docs/`의 경계

| | `.agents/` | `docs/` |
|---|---|---|
| 답하는 질문 | **에이전트가 어떻게 일하는가** | **모듈이 무엇이고 왜 그렇게 만들었는가** |
| 주 독자 | 코딩 에이전트 (사람도 읽음) | 사람 기여자·시험기관 (에이전트도 읽음) |
| 에이전트 도구를 다 걷어내면 | **없어도 된다** | **남아야 한다** |
| 예 | 역할 정의, 작업 루프, 도구 매핑, glob 규칙 | 기획서, 계약, 테스트 전략, Rust 규약, ADR, KCMVP 제출물 초안 |

> **판단이 애매하면**: "AI 에이전트를 전혀 쓰지 않는 팀(또는 시험기관)에게도 이 문서가 필요한가?"
> 필요하면 `docs/`, 아니면 `.agents/`.
>
> 그래서 `docs/CONTRACTS.md`(C1~C5)는 `docs/`에 있다. 그것은 **모듈의 약속**이지 에이전트 지침이 아니다.
> 형상관리문서는 개발 절차를 설명해야 하므로, 이 디렉터리의 **절차**(교차 리뷰, 승인 경계)는
> `docs/kcmvp/` 에 사람이 요약해 옮긴다. 에이전트 도구 설정 자체는 제출물이 아니다.

## 표준에 대한 정직한 설명

비준된 규약은 **루트 `AGENTS.md` 하나**다 (agents.md 규약 — Codex, Cursor, opencode 등이 채택).
`.agents/` 디렉터리는 공식 스펙이 **아니다.** 서브에이전트 정의는 각 도구가 자기 네임스페이스를 쓴다
(`.claude/agents/`, `.opencode/agent/`, `.codex/agents/`, `.cursor/rules/`).

`.agents/` 를 두는 이유는 표준 준수가 아니라 **중복 제거**다:
다섯 도구가 같은 역할·같은 규칙을 각자 복제하면 반드시 어긋난다.
각 도구의 파일은 여기를 가리키는 얇은 스텁·생성물·symlink 로 유지한다.

```
AGENTS.md            ← 표준 진입점. 절대 규칙 R1~R10, 계약 요약, 작업 루프 개요
  │
  ├─ .agents/ROLES.md          역할 13종 색인
  ├─ .agents/WORKFLOW.md       6단계 루프 상세 (진입/종료 조건)
  ├─ .agents/APPROVAL.md       승인 경계 설명 (정의: scripts/hooks/protected.tsv)
  ├─ .agents/INDEPENDENCE.md   오라클·레드팀·리뷰어 독립성 절차
  ├─ .agents/COMPATIBILITY.md  도구별 매핑과 폴백, 검증 기록
  ├─ .agents/roles/*.md        역할 정의 (원천)
  ├─ .agents/rules/*.md        경로(glob)별 규칙 조각 (원천)
  └─ .agents/workflows/*.md    명령 절차 (원천)
       │
       ├─ .claude/agents/*.md     → 생성 (frontmatter + 본문)
       ├─ .opencode/agent/*.md    → 생성
       ├─ .codex/agents/*.toml    → 생성
       ├─ .claude/rules/*.md      → symlink
       ├─ .cursor/rules/*.mdc     → symlink
       └─ .claude/commands/jms-*.md · .cursor/commands/*.md · .opencode/command/*.md → symlink
```

## 파일

| 파일 | 내용 |
|---|---|
| `WORKFLOW.md` | ① SPEC → ② HARNESS → ③ IMPL → ④ VERIFY → ⑤ REVIEW → ⑥ RECORD |
| `APPROVAL.md` | 승인 경계 설명 — 정의는 `scripts/hooks/protected.tsv` (판정: `judge.py`) |
| `INDEPENDENCE.md` | 오라클·레드팀·리뷰어 독립성을 **절차**로 지키는 방법 |
| `COMPATIBILITY.md` | 도구 매핑, 폴백, prist 대비 변경점, **검증 기록** |
| `roles/*.md` | 역할 13종. frontmatter 에 `model`·`sandbox`·`tools`·`fresh_session`·`forbid_read` |
| `rules/*.md` | 경로별 규칙. `paths`(Claude) + `globs`(Cursor) 를 함께 보유 |
| `workflows/*.md` | 명령 절차. 세 도구에 symlink 된다 |

## `rules/` 사용법

각 파일은 **특정 경로를 편집할 때 적용되는 규칙**만 담는다.

| 파일 | 적용 경로 |
|---|---|
| `core.md` | 항상 |
| `review-commit.md` | 항상 |
| `rust.md` | `**/*.rs` |
| `crypto-core.md` | `crates/jamulsoe-core/**` |
| `module.md` | `crates/jamulsoe-module/**` |
| `ffi.md` | `crates/jamulsoe-ffi/**`, `include/**`, `exports.txt`, `bindings/**` |
| `testing.md` | `tests/**`, `**/tests/**`, `fuzz/**` |
| `harness.md` | `crates/jamulsoe-oracle/**`, `crates/jamulsoe-ct/**` |
| `build.md` | `tools/**`, `.github/**`, `rust-toolchain.toml`, `Cargo.toml`, `build/**` |
| `kcmvp-docs.md` | `docs/kcmvp/**`, `docs/provenance.md` |

**규칙 조각에 규칙 전문을 쓰지 않는다.** `docs/CONTRACTS.md`, `docs/RUST-GUIDE.md`, `docs/TESTING.md` 등을 가리키고,
**그 경로에서 가장 자주 틀리는 것 3~8개**만 콕 집어 적는다. 길면 읽히지 않는다.

## 규칙을 바꾸는 법

`.agents/**` 와 `AGENTS.md` 는 사람 승인 경로다 — 에이전트가 자기 제약을 풀 수 없게 하기 위해서다.
에이전트는 바꿀 내용을 제안하고, 사람이 아래 절차로 반영한다 (`JMS_APPROVED_BY=<이름> git commit -s -S`).

1. `.agents/` 의 원천을 고친다
2. `./scripts/sync-agents.sh` 로 생성물을 갱신한다
3. 원천과 생성물을 **같은 커밋**에 넣는다 (`pre-commit` 이 드리프트를 거부한다)

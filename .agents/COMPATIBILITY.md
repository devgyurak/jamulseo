# 도구 호환성 — claude-code / codex / pi / opencode / cursor

## 설계 원칙: **하나의 원천, 다섯 개의 어댑터, 하나의 게이트**

```
                         AGENTS.md  (단일 원천)
                              │
      ┌──────────┬────────────┼────────────┬──────────────┐
      ▼          ▼            ▼            ▼              ▼
  CLAUDE.md   .codex/      .pi/       .opencode/    .cursor/rules/
  .claude/    agents/      config.toml  opencode.json  *.mdc
      │          │            │            │              │
      └──────────┴────────────┼────────────┴──────────────┘
                              ▼
                        scripts/*.sh          ← 진짜 게이트
                              │
      ┌───────────────────────┼───────────────────────┐
      ▼                       ▼                       ▼
  도구 훅 (빠른 피드백)   .githooks/ (커밋·push)    CI (최종)
```

**왜 이렇게 하는가**: 다섯 도구의 훅 스키마가 전부 다르고, 일부는 훅이 없거나 버전마다 바뀐다.
강제 로직을 훅에 흩어 놓으면 "cursor 로 작업하면 통과하는데 codex 로 하면 막힌다" 같은 상태가 된다.
**로직은 `scripts/hooks/` 한 곳에만 둔다. 도구 훅은 그것을 부르는 몇 줄짜리 어댑터다.**

---

## 기능 지원 매트릭스

| 기능 | claude-code | codex | pi | opencode | cursor |
|---|---|---|---|---|---|
| 프로젝트 지침 | `CLAUDE.md` (→`@AGENTS.md`) | `AGENTS.md` | `AGENTS.md` | `AGENTS.md` | `.cursor/rules/*.mdc` |
| 규칙 (glob 조건부) | `.claude/rules/` `paths:` | `AGENTS.md` 섹션 | `AGENTS.md` 섹션 | `AGENTS.md` | **`.mdc` `globs:`** |
| 서브에이전트 | `.claude/agents/*.md` | `.codex/agents/*.toml` | 세션 분리로 근사 | `.opencode/agent/*.md` | 세션 분리로 근사 |
| 커스텀 명령 | `.claude/commands/jms-*.md` | 프롬프트 파일 | 프롬프트 파일 | `.opencode/command/*.md` | `.cursor/commands/*.md` |
| 훅 | `.claude/settings.json` | (제한적) | (제한적) | `.opencode/plugin/*.js` | `.cursor/hooks.json` |
| **폴백** | — | `.githooks/` + `scripts/` | `.githooks/` + `scripts/` | — | `.githooks/` + `scripts/` |

> **훅 지원이 약한 도구에서는 `.githooks/` 가 같은 검사를 한다.**
> `./scripts/bootstrap.sh` 가 `git config core.hooksPath .githooks` 를 설정한다.

---

## 공통 훅 구현 (`scripts/hooks/`)

| 스크립트 | 입력 | 종료 코드 규약 |
|---|---|---|
| `guard-protected.sh` | 도구 JSON(stdin) 또는 `<경로> [<내용 파일>]` + `JMS_*` 환경. 정책은 `protected.tsv`, 판정은 `judge.py` | 0 허용 / **2 차단** |
| `guard-antipatterns.sh` | 도구 JSON(stdin) 또는 `<경로> <내용 파일>` | 0 깨끗함 / **1 경고 있음** (stderr) |
| `post-edit.sh` | 도구 JSON(stdin) 또는 `<경로>` | 0 깨끗함 / **1 경고 있음** (stderr) |
| `stop-check.sh` | 도구 JSON(stdin, 선택) | 0 / **1 상기 필요** (stderr) |
| `session-context.sh` | 없음 | 0, stdout 이 컨텍스트 |

"경고 = 1" 을 도구 어댑터가 각자의 방식으로 바꾼다. 차단(2)과 경고(1)를 섞지 않는다.

## prist 대비 바꾼 것

| 무엇 | prist | jamulsoe | 이유 |
|---|---|---|---|
| 반패턴 경고 시점 | Claude `PreToolUse`, exit 0 | Claude `PostToolUse`, 경고 시 exit 2 | Claude Code 는 exit 0 의 stderr 를 모델에 보여주지 않는다. 경고가 **에이전트에게 닿지 않았다** |
| 편집 후 clippy·GWT 경고 | exit 0 | 경고 시 exit 2 (PostToolUse) | 같은 이유 |
| Stop 훅 | exit 0 (사람만 봄) | 한 번 exit 2, `stop_hook_active` 면 0 | 에이전트가 게이트를 돌리게 하되 무한 반복을 막는다 |
| pre-push | 전체 게이트 | 작업 브랜치: 정적 게이트 / main: `--fast` | 증분 작업 경로가 막히던 문제 (prist ADR-0102 제안). 빨간 테스트 커밋은 작업 브랜치에만 |
| R1 의 위치 | 단계 P0 에 빨간 테스트를 통합 브랜치에 둠 | 하네스와 구현을 같은 PR, 테스트 커밋 먼저 | 통합 브랜치(`develop`)가 빨개지면 이후 모든 PR 이 막힌다 |
| 판정 상태 | 통과 / 실패 / 미적용 | + **실행 불가**(플랫폼) | 검증 대상 환경이 Linux x86_64 하나뿐이라 macOS 로컬 결과를 통과로 셀 수 없다 |
| 도메인 반패턴 | 비결정성(R7) | 비밀값 분기·테이블 조회·패닉·`Box::new`·`offset_from`·`ptr::write` | 계약 C1·C2·C4 |
| 보호 범위 | 게이트 스크립트 몇 개 | `scripts/**` 전체, 에이전트 규약, 도구 훅 설정, 레지스트리 판정 | 판정되는 쪽이 판정기를 고칠 수 없게 |
| 보호 목록 원천 | 판정기·commit-msg·문서에 각각 | `protected.tsv` 하나 | 목록이 어긋나면 한쪽만 강제된다 |
| 서버 판정 | PR 의 스크립트 실행, 트레일러 존재만 확인 | base 의 워크플로·스크립트(`pull_request_target`), 승인자 목록 + SSH 서명 검증 | 같은 PR 안에서 판정기를 무를 수 없게, 트레일러를 증거로 |
| 스크립트 실행 권한 | `scripts/*.sh` 와일드카드 | 이름별 나열 | 새 스크립트로 모든 규칙을 우회하는 통로를 닫는다 |

---

## 도구별 설정

### claude-code

```
CLAUDE.md                  → @AGENTS.md import + Claude 전용 운용
.claude/settings.json      → 훅 4개 이벤트, 권한 — 손으로 관리
.claude/hooks/*.sh         → scripts/hooks/ 호출 어댑터 — 손으로 관리
.claude/agents/*.md        → 서브에이전트 13종 (생성물)
.claude/rules/*.md         → 규칙 (symlink)
.claude/commands/jms-*.md  → 슬래시 명령 12종 (symlink)
```

### codex

```
AGENTS.md                  → 그대로 읽힘
.codex/agents/*.toml       → 서브에이전트 13종 (생성물)
.codex/config.toml         → 기본값, 프로필 — 손으로 관리
```

`sandbox_mode = "read-only"` 가 리뷰어·레드팀의 **쓰기**를 막는다.
**읽기 경로 제한은 강제하지 못하므로** 독립성은 `.agents/INDEPENDENCE.md` 의 절차로 지킨다.

### pi

```
AGENTS.md                  → 그대로 읽힘
.pi/config.toml            → 제네릭 어댑터
```

> ⚠️ **확인 필요**: pi 의 설정 파일 경로·스키마는 버전에 따라 다를 수 있다.
> `.pi/config.toml` 은 **제네릭 템플릿**이다. pi 가 `AGENTS.md` 만 읽어도 워크플로우는 성립한다.

### opencode

```
AGENTS.md                         → 그대로 읽힘
.opencode/opencode.json           → 권한, 기본 에이전트
.opencode/agent/*.md              → 에이전트 (생성물)
.opencode/command/*.md            → 명령 (symlink)
.opencode/plugin/jamulsoe-gates.js → 훅 (도구 실행 전후)
```

### cursor

```
.cursor/rules/*.mdc        → glob 조건부 규칙 (symlink)
.cursor/commands/*.md      → 명령 (symlink)
.cursor/hooks.json         → 훅
```

> ⚠️ cursor 의 훅 이벤트 이름은 버전에 따라 다르다. 동작하지 않으면 `.githooks/` 에 의존해도 된다.

---

## 역할 분리를 도구가 지원하지 않을 때 (pi / cursor)

1. **세션을 나눈다.** 구현 세션을 끝내고 새 세션을 연다
2. `.agents/roles/<이름>.md` 를 첫 메시지로 넣는다
3. `oracle-author` / `spec-redteam` 세션에서는 `./scripts/spec-bundle.sh --for <역할>` 묶음만 연다
4. PR 본문에 "구현 세션 / 리뷰 세션이 분리되었는가"를 체크

---

## 새 도구를 추가할 때

1. `AGENTS.md` 를 읽게 한다
2. 지원하지 않으면 그 도구의 지침 파일에 `AGENTS.md` 를 가리키는 3줄짜리 스텁을 만든다
3. **규칙을 복제하지 않는다**
4. 훅을 지원하면 `scripts/hooks/` 를 호출하는 어댑터만 작성하고, 종료 코드 규약을 지킨다
5. 이 표에 행을 추가하고 `scripts/sync-agents.sh` 에 생성 규칙을 추가한다

---

## 공통 부트스트랩

```bash
./scripts/bootstrap.sh
```

- `python3` ≥ 3.11 확인 (보호 경로 판정·경계 린트가 요구한다. 없으면 **모든 편집이 차단된다**)
- `rust-toolchain.toml` 의 툴체인, nightly(miri·fuzz·ASan) 설치
- cargo 도구 설치 (nextest, llvm-cov, mutants, fuzz, cbindgen, show-asm)
- `git config core.hooksPath .githooks`

---

## 검증 기록

`./scripts/check-adapters.sh` 는 링크와 드리프트만 확인한다.
**도구가 실제로 로드하는지**는 실세션에서만 알 수 있다. 확인할 때마다 여기 남긴다.

| 날짜 | 도구 | 버전 | 규칙 로딩 | 역할 인식 | 훅 동작 | 비고 |
|---|---|---|---|---|---|---|
| — | claude-code | | ☐ | ☐ | ☐ | 미확인 |
| — | codex | | ☐ | ☐ | — | 미확인 |
| — | cursor | | ☐ | — | ☐ | **symlink `.mdc`→`.md` 인식 여부 확인 필요** |
| — | opencode | | ☐ | ☐ | ☐ | 미확인 |
| — | pi | | ☐ | — | — | **설정 스키마 미확인** |

미확인 항목을 "동작한다"고 문서에 쓰지 않는다. 그것이 이 표가 있는 이유다.

# 승인 경계

> 문서에 적힌 보장과 실제 검사가 어긋나면, 문서는 거짓말이 된다.
> **기계가 읽는 유일한 정의는 `scripts/hooks/protected.tsv`** 다. 이 문서는 그 표의 설명이다.
> 판정기(`judge.py`), `.githooks/commit-msg`, `check-adapters.sh`(Claude 권한 대조)가 모두 그 파일 하나를 읽는다.

## 원칙

**에이전트는 자기를 판정하는 것을 고칠 수 없다.** 게이트 스크립트, 판정기, 계약, 기준선, 에이전트 규약,
도구 훅 설정, 정답 데이터가 여기에 속한다. 고쳐야 하면 이유를 정리해 사람에게 요청하고 멈춘다.

## 판정 종류

| 종류 | 에이전트가 할 수 있는 것 | 대상 |
|---|---|---|
| `human` | 없음 (추가·수정·삭제 모두 사람) | `docs/PLAN.md`, `docs/CONTRACTS.md`, `docs/kcmvp/inquiries.md`, `exports.txt`, `include/jamulsoe.h`, `rust-toolchain.toml`, `build/baseline.toml`, `tests/mutants/exempt.toml`, `AGENTS.md`, `CLAUDE.md`, `.agents/**`, **`scripts/**` 전체**, `.githooks/**`, `.github/**`, 도구 훅·권한 설정(`.claude/settings*.json`, `.claude/hooks/**`, `.cursor/hooks*`, `.opencode/opencode.json`, `.opencode/plugin/**`, `.codex/config.toml`, `.pi/config.toml`) |
| `human` (생성물) | 없음 — 원천(`.agents/`)과 함께 사람이 `sync-agents.sh` 로 갱신 | 도구가 실제로 읽는 생성물: `.claude/agents/**`, `.claude/rules/**`, `.claude/commands/**`, `.codex/agents/**`, `.opencode/agent/**`, `.opencode/command/**`, `.cursor/rules/**`, `.cursor/commands/**` |
| `human` (승인 감사) | 없음 | `docs/audits/attested/**` — 레지스트리 `attest: human` 단계의 증거 (기준 장비 dudect 기록 등) |
| `new-only` | 새 파일 추가만 | `tests/vectors/*`(데이터), `tests/negative/*`, `docs/standards/*`, `docs/audits/*` (attested 제외) |
| `append` | 새 파일, 또는 기존 내용 **끝에** 줄 붙이기만 | `tests/vectors/SOURCES.md`, `tests/negative/README.md`, `docs/standards/SOURCES.md` |
| `registry` | 항목 추가, 단계의 `test` 이름 추가, `evidence` 채우기·갱신 | `tests/contracts/registry.json` |
| `adr` | `제안` 상태 ADR 생성·수정 | `docs/adr/*.md` |

`registry` 에서 막히는 것: 항목 삭제, 단계 추가·삭제, **마일스톤 변경**, **검사 종류 변경**(예: `test` → `manual`),
연결된 테스트 제거, `evidence` 비우기, **감사 최소 범위(`scope`) 축소**, **`attest` 변경**, 판정할 수 없는 JSON. 게다가 `contract_check.py` 가 레지스트리의 마일스톤을
`docs/CONTRACTS.md`(human)와 대조하므로, 레지스트리만 고쳐서는 마일스톤을 미룰 수 없다.

`adr` 에서 막히는 것: `채택`·`대체됨`·**`기각`** 으로의 전환, 그 상태인 ADR 의 수정(기각을 `제안` 으로 되돌리는 것 포함),
ADR 삭제, 비정규 상태 표기, **`방향 확인` 필드 채우기·바꾸기**(새 ADR 은 `대기` 여야 한다), 머리말에 `방향 확인` 줄을 둘 이상 두기.

`append` 가 "부분 수열"이 아니라 "끝에 붙이기"인 이유: 부분 수열이면 기존 벡터 레코드 안에 `CT = ...` 줄을 끼워 넣어
기대값을 바꿀 수 있었다. 벡터 **데이터** 파일은 끝에 붙이는 것도 막고 새 파일만 허용한다.

경로는 문자열이 아니라 **파일 정체성**으로 판정한다 — 디스크의 실제 이름(대소문자·유니코드 변형),
가장 가까운 git 작업 트리 기준 경로, casefold 한 이름 중 하나라도 보호 대상이면 그 규칙이 적용된다.

## 강제 지점 — 네 겹

```
                 scripts/hooks/protected.tsv  (정의)
                              │
                 scripts/hooks/judge.py       (판정)
                              ▲
  ┌──────────────┬────────────┼─────────────┬──────────────────────────────┐
  │              │            │             │                              │
.claude/hooks  .cursor/    .opencode/   .githooks/pre-commit         CI protected.yml
(PreToolUse)   hooks       plugin       (+ commit-msg 별도 커밋)      (base 의 판정기·워크플로)
```

1. **도구 훅** — 편집 직전 차단. 빠른 피드백
2. **도구 권한** — Claude `permissions.deny` 의 `Edit(...)`. 훅이 꺼져도 남는다. `check-adapters.sh` 가 `human` 항목을 빠짐없이 덮는지 대조한다.
   스크립트 실행 허용은 **이름별로** 나열한다 (`scripts/*` 와일드카드는 에이전트가 새 스크립트를 써서 모든 규칙을 우회하는 통로가 된다)
3. **git 훅** — `pre-commit` 이 스테이지 내용으로 판정, `commit-msg` 가 사람 승인 경로의 별도 커밋과 `Approved-by:` 를 요구
4. **CI (최종)** — 아래 §서버 측 강제

로컬 세 겹은 셸 편집(`sed -i`), `--no-verify`, 훅 미설치로 우회될 수 있다. **우회하지 않는다.** 우회한 변경은 CI 에서 막히고 이력에 남는다.

## 실패 시 동작 — fail-closed

| 실패 | 동작 |
|---|---|
| 입력 JSON 을 해석하지 못함 (잘림·문법 오류·객체 아님) | 차단 |
| 해석기·판정기가 예외로 종료하거나 완료 표식이 없음 | 차단 |
| 판정기 구성 요소(`judge.py`, `protected.tsv` 등)·`python3` 이 없음 | 차단 |
| 정책 파일 형식 오류 | 차단 |
| Git 변경 목록·HEAD·스테이지 조회 실패 | `pre-commit` 차단 |
| opencode 보호 훅이 0 이외의 종료 코드 | 차단 (`throw`) |

**"유효한 입력인데 편집 대상이 없는 경우"와 "입력을 해석하지 못한 경우"는 다르다.** 전자는 허용, 후자는 차단한다.

## 승인 기록

`--no-verify` 는 모든 검사를 끄고 이력에 아무것도 남기지 않는다. 승인 경로로 쓰지 않는다.

```bash
JMS_APPROVED_BY=devgyurak git commit -s -S     # 메시지에 Approved-by: devgyurak, 승인자 키로 서명
```

- `pre-commit` 은 보호 경로 판정만 건너뛰고 나머지 검사는 그대로 돈다
- `commit-msg` 는 `Approved-by:` 트레일러를 요구하고, 사람 승인 경로를 다른 변경과 섞지 못하게 한다
- 서명은 `.github/allowed_signers` 에 등록한 **승인자의 SSH 키**(하드웨어 승인 키)로 한다. 모든 커밋은 "서명 필수" 규칙 때문에 일상 키로도 서명되지만, 일상 키는 `allowed_signers` 에 없으므로 승인이 아니다 (`docs/RELEASE.md` §서명 키)

## 서버 측 강제

`.github/workflows/protected.yml` 이 `pull_request_target` 으로 돈다. 즉 **워크플로 파일과 실행되는 스크립트가 base 브랜치의 것**이다.
PR 의 커밋은 git 객체로만 가져오고 실행하지 않는다. `scripts/check-protected-diff.sh`(base 의 것)가 각 커밋을:

1. `Signed-off-by:` (DCO) 확인
2. base 의 판정기로 보호 경로 변경 여부 판정
3. 보호 경로 변경이 있으면 — `Approved-by: <이름>` 의 이름이 base 의 `.github/APPROVERS` 에 있고,
   커밋이 그 승인자 이메일의 키로 **유효하게 서명**되었는지(`.github/allowed_signers`, `%G? = G`, 서명자 = 승인자) 확인

머지 커밋은 **모든 부모와 다른 파일만** 판정한다 (`git diff-tree -c`) — 승인된 PR 을 그대로 머지한 커밋은 대상이 없고,
머지 커밋에서 따로 고친 보호 파일(evil merge)만 걸린다. 내용을 바꾸지 않은 머지 커밋은 DCO 에서도 제외한다.
**스쿼시·리베이스 머지는 쓰지 않는다** — 승인자 서명이 사라져 이 검사에 실패한다 (`docs/RELEASE.md`).

같은 PR 안에서 판정기·워크플로·승인자 목록·서명자 목록을 무를 수 없다. 이 job 을 규칙셋의 required status check 로 지정한다 (사람이 설정).

> **한계 — 서명은 키를 가진 쪽을 증명할 뿐이다.** 에이전트가 승인자의 서명 키를 쓸 수 있는 환경이면 서명도 증거가 아니다.
> 승인 키는 하드웨어 키(`ed25519-sk`, 서명마다 터치)나 에이전트 세션의 ssh-agent 에 올리지 않는 별도 키로 둔다.
> 이 한계와 대책은 형상관리문서에도 그대로 적는다.

## 검증

`scripts/selftest-gates.sh` 가 각 종류의 허용·차단 사례와, 미서명·목록 밖 승인자·다른 키 서명을 실제로 판정기와
`check-protected-diff.sh` 에 넣어 확인한다. **`protected.tsv` 에 행을 추가하면 자기 시험에도 항목을 추가한다.**

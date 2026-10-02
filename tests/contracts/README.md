# 계약 레지스트리

`registry.json` 은 `docs/CONTRACTS.md` 의 조항 ID 마다 그것을 막는 검사를 연결한다.
`./scripts/contract-check.sh` 가 **역방향**으로 검사한다: 현재 마일스톤 이하의 조항마다 실행되는 검사가 있는가.

| 필드 | 뜻 |
|---|---|
| `id` | 조항 ID (`C2-01`) — `docs/CONTRACTS.md` 에 있어야 한다 |
| `stages[]` | 마일스톤별 단계. 마일스톤 집합 = `docs/CONTRACTS.md` 의 마일스톤 열 |
| `stages[].milestone` | 이 단계가 필수가 되는 마일스톤 |
| `stages[].check` | `test` / `gate:<스크립트 이름>` / `manual` / `policy` |
| `stages[].test` | `check = test` 일 때 `<크레이트>::<테스트 함수 이름>` 배열 (`#[ignore]` 는 증거가 아니다) |
| `stages[].evidence` | `manual`: `docs/audits/` 의 감사 파일 (`docs/audits/README.md`) / `policy`: 절차 문서 |
| `stages[].scope` | `manual`: 감사가 반드시 덮어야 하는 최소 경로 (넓히기만 가능) |
| `stages[].attest` | `"human"` 이면 `docs/audits/attested/`(사람 전용)의 기록만 인정 |

## 두 판정 모드

| 모드 | 언제 | 미연결 단계 | 연결된 증거 |
|---|---|---|---|
| 머지 판정 | 매 CI (`contract-check.sh`) | **대기** — 증분 작업이 가능하다 | 반드시 유효 (`#[ignore]` 아님, 감사 형식·범위). 낡은 감사는 경고 |
| 종료 판정 | `verify.sh --milestone` (`contract-check.sh --exit`) | **실패** | 반드시 유효 + 낡은 감사도 실패 |

판정기가 연결 제거를 막으므로, 머지 판정이 미연결을 허용해도 이미 연결된 증거가 후퇴하지는 않는다.

## 규칙

- 판정기(`scripts/hooks/judge.py`)가 **항목 추가, `test` 이름 추가, `evidence` 갱신만** 허용한다.
  항목·단계 삭제, 마일스톤·검사 종류 변경, 테스트 제거는 사람만
- 테스트를 연결할 때는 그 검사를 무력화하면 테스트가 실패하는지 확인한다 (`./scripts/mutants.sh`)
- `docs/CONTRACTS.md` 에 조항이 추가되면 여기도 추가한다 (`contract-check` 가 누락을 잡는다)

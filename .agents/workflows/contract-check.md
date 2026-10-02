---
description: 계약 C1~C5 · 불변식 I1~I5 의 항목마다 실행되는 테스트가 있는지 역방향으로 확인
argument-hint: [--milestone Mx]
---

```
./scripts/contract-check.sh $ARGUMENTS
```

## 이것이 커버리지와 다른 점

커버리지는 "코드가 실행됐나"를 본다. 이 검사는 **"계약 조항마다 테스트가 있나"** 를 **역방향으로** 본다.

`tests/contracts/registry.json` 의 각 항목은 마일스톤별 **단계(stages)** 를 갖는다. 단계의 마일스톤 집합은
`docs/CONTRACTS.md` 의 마일스톤 열과 같아야 한다 (레지스트리만 고쳐서 미룰 수 없다).
현재 마일스톤 이하의 단계는:

| 검사 | 통과 조건 |
|---|---|
| `test` | 연결된 테스트가 실행 목록에 있고 `#[ignore]` 가 아니다 |
| `gate:X` | `scripts/X.sh` 가 있고 `verify.sh` 에 등록되어 있다 |
| `manual` | `evidence` 가 `docs/audits/` 의 감사 파일이고, `verdict: pass`, 툴체인이 현재와 같고, 감사 커밋 이후 `scope` 가 바뀌지 않았다 |
| `policy` | `evidence` 파일이 있다 (절차 문서 — 가장 약한 증거) |

이후 마일스톤 단계는 "대기"로 표시되며 통과로 세지 않는다.

**두 모드** — 매 CI 는 머지 판정: 아직 연결하지 않은 단계는 "대기", 연결된 증거만 검사한다 (낡은 감사는 경고).
마일스톤 종료(`--exit`, `verify.sh --milestone`)에서만 모든 단계를 요구한다.
manual 증거는 레지스트리의 최소 범위(`scope`)를 덮어야 하고, `attest: human` 단계는 `docs/audits/attested/`(사람 전용) 기록만 인정한다.

## 누락이 나왔을 때

1. `docs/CONTRACTS.md` 에서 해당 조항을 읽는다
2. GWT 테스트를 추가하고 레지스트리 해당 단계의 `test` 에 이름을 추가한다 (`<크레이트>::<테스트 이름>`).
   manual 단계가 낡았으면(툴체인·코드 변경) `ct-auditor` 등으로 **다시 감사**해 새 감사 파일을 연결한다
3. **그 검사를 일부러 무력화하면 실패하는지** 확인한다 — 그래야 테스트가 실제로 잡는 것이다

```
./scripts/mutants.sh --only <파일>
```

## 절대 하지 말 것

- 레지스트리에서 항목을 지우거나, 마일스톤·검사 종류를 바꿔서 통과시키기 (판정기가 막는다)
- `docs/CONTRACTS.md` 를 직접 수정하기 (R4 — 훅이 차단한다)

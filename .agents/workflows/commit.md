---
description: 규약에 맞는 커밋을 만든다 (ADD/FIX/REF/UPT/DEL/TEST/DOCS + Signed-off-by)
argument-hint: [메시지 힌트]
---

## 절차

1. `git status` · `git diff --cached` 로 **무엇이 스테이지되었는지** 확인한다
2. **한 커밋 = 한 관심사**인지 확인한다. 아니면 나눈다
3. **보호 파일**(`.agents/APPROVAL.md`)이 섞여 있으면 **반드시 별도 커밋**으로 분리하고, 사람에게 넘긴다 (훅이 거부한다)
4. `.agents/` 를 고쳤으면 `./scripts/sync-agents.sh` 결과도 같은 커밋에 넣는다
5. 타입을 고르고 `Contracts:` 트레일러를 채운다 — **"none"이라고 쓰기 전에 한 번 더 생각한다**
6. `git commit -s` 로 `Signed-off-by:` 를 붙인다 (DCO, 모든 커밋)

## 타입 선택

| 타입 | 용도 |
|---|---|
| `ADD:` | 새 기능·파일·API |
| `FIX:` | **버그 수정** — 재현 테스트가 함께 스테이지되어야 한다 |
| `REF:` | **리팩터링 — 동작 불변** |
| `UPT:` | **의존성·툴체인 업데이트** |
| `DEL:` | 기능·파일 제거 |
| `TEST:` | 테스트, **하네스**(`jamulsoe-oracle`/`jamulsoe-ct`), 정답 벡터, 실패 코퍼스, 퍼징 |
| `DOCS:` | 문서·주석·ADR·KCMVP 제출물 초안·provenance |

**`FIX:` vs `REF:`**: *"이 변경 없이도 기존 테스트가 전부 통과하는가?"*
- 통과한다 → `REF:` / 실패하는 테스트가 있었다 → `FIX:`

## 형식

```
<TYPE>(<범위>): <한 줄 요약>      # 범위는 선택 — core | module | ffi | ct | oracle | build | kcmvp | agents

<본문: 왜 이렇게 했는지. 무엇을 했는지는 diff 가 말한다>

Contracts: C1, C4 | none         # ADD / FIX / REF 에 필수
Invariants: I2                   # 선택
Milestone: M1                    # 권장
Review: P1 0 / P2 1 해소          # 머지 커밋에 권장
Refs: docs/adr/0003-....md
Signed-off-by: 이름 <email>       # 모든 커밋 (git commit -s)
```

전문: `docs/COMMIT.md` · 훅: `.githooks/commit-msg` 가 형식을 강제한다.

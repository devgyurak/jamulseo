---
description: ③ IMPL — 하네스를 통과시키는 최소 구현
argument-hint: <크레이트 | 기능>
---

대상: **$ARGUMENTS**

## 전제 확인

먼저 확인한다. 아니면 `/jms-harness` 로 돌아간다:
- [ ] 실패하는 테스트가 이미 있는가? (정답 벡터·실패 코퍼스·계약 테스트)
- [ ] 이 변경이 건드리는 계약이 식별되었는가?
- [ ] 지금 마일스톤에서 해도 되는 작업인가? (**G1 전에는 core 만**, `docs/ROADMAP-STATUS.md`)

## 절차

크레이트에 맞는 서브에이전트를 쓴다:

| 크레이트 | 에이전트 | 규칙 |
|---|---|---|
| `jamulsoe-core` | `core-engineer` | `.agents/rules/crypto-core.md` |
| `jamulsoe-module` | `module-engineer` | `.agents/rules/module.md` |
| `jamulsoe-ffi`, `bindings/` | `ffi-engineer` | `.agents/rules/ffi.md` |
| 워크스페이스·빌드·`tools/` | `build-engineer` | `.agents/rules/build.md` |

구현 후 `./scripts/verify.sh --fast`.
외부 자료를 참고했다면 같은 PR 에서 `docs/provenance.md` 에 기록한다 (R9).

## 철칙

- **테스트를 통과시키는 최소 구현.** 앞서가지 않는다
- **테스트·정답 벡터·코퍼스를 고치지 않는다.** 틀렸다고 판단하면 근거를 대고 **멈춰서 사람에게 묻는다**
- 비밀값으로 분기·인덱싱하지 않는다 (C1). 확신이 없으면 `/jms-ct` 를 먼저 돌린다
- 출력은 모든 검사를 통과한 뒤에만 쓴다 (I1)
- 경계 크레이트에 외부 의존을 추가하지 않는다 (R8)
- 한 커밋 = 한 관심사

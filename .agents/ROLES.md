# 역할 색인

> 역할 정의는 `.agents/roles/<이름>.md` 로 분리되어 있다. 이 파일은 색인이다.
> 도구별 파일(`.claude/agents/` · `.opencode/agent/` · `.codex/agents/`)은
> `scripts/sync-agents.sh` 가 생성하므로 **직접 수정하지 않는다**.

| 단계 | 역할 | 독립 세션 | 정의 |
|---|---|---|---|
| ① SPEC | `spec-author` | | [roles/spec-author.md](roles/spec-author.md) |
| ① SPEC | `spec-redteam` | 🚫 **구현 안 봄** | [roles/spec-redteam.md](roles/spec-redteam.md) |
| ② HARNESS | `harness-engineer` | | [roles/harness-engineer.md](roles/harness-engineer.md) |
| ② HARNESS | `oracle-author` | 🚫 **경계 구현 안 봄** | [roles/oracle-author.md](roles/oracle-author.md) |
| ③ IMPL | `core-engineer` | | [roles/core-engineer.md](roles/core-engineer.md) |
| ③ IMPL | `module-engineer` | | [roles/module-engineer.md](roles/module-engineer.md) |
| ③ IMPL | `ffi-engineer` | | [roles/ffi-engineer.md](roles/ffi-engineer.md) |
| ② / ③ | `test-engineer` | | [roles/test-engineer.md](roles/test-engineer.md) |
| ③ / ④ | `build-engineer` | | [roles/build-engineer.md](roles/build-engineer.md) |
| ⑤ REVIEW | `rust-reviewer` | 🚫 **구현자와 분리** | [roles/rust-reviewer.md](roles/rust-reviewer.md) |
| ⑤ REVIEW | `contract-auditor` | 🚫 **구현자와 분리** | [roles/contract-auditor.md](roles/contract-auditor.md) |
| ⑤ REVIEW | `ct-auditor` | 🚫 **구현자와 분리** | [roles/ct-auditor.md](roles/ct-auditor.md) |
| ⑥ RECORD | `kcmvp-writer` | | [roles/kcmvp-writer.md](roles/kcmvp-writer.md) |

독립 세션이 필요한 역할의 절차: **`.agents/INDEPENDENCE.md`**

## prist 대비 바뀐 것

| prist | jamulsoe | 이유 |
|---|---|---|
| storage / txn / sql / agent-surface / crypto -engineer | `core` / `module` / `ffi` -engineer | 크레이트 경계 = 검증 책임 경계 (알고리즘 / 상태·자가시험 / unsafe·ABI) |
| bench-engineer | `build-engineer` | 성능 기준선보다 **재현 빌드·툴체인 기준선·무결성 태그**가 검증의 근거다 |
| — | `ct-auditor` | 상수 시간(C1)은 일반 리뷰로 잡히지 않는다. 어셈블리까지 보는 별도 리뷰어 |
| — | `kcmvp-writer` | 제출물(설계서·보안정책문서·형상관리)은 코드와 함께 자라야 한다 |

## 모든 역할 공통

### 코드 리뷰 심각도 (`docs/CODE-REVIEW.md`)
`[P1]` 치명(머지 차단) / `[P2]` 높음(수정 또는 이슈+기한) / `[P3]` 제안(선택).
심각도는 **항상 대괄호**로 쓴다.

### 커밋 타입 (`docs/COMMIT.md`)
`ADD:` 추가 / `FIX:` **버그 수정**(재현 테스트 필수) / `REF:` **리팩터링**(동작 불변) /
`UPT:` **의존성·툴체인 업데이트** / `DEL:` 제거 / `TEST:` 테스트·하네스·벡터·코퍼스 / `DOCS:` 문서·ADR·제출물 초안

하네스 크레이트(`jamulsoe-oracle`/`jamulsoe-ct`)·퍼징·코퍼스 작업은 **`TEST:`** 다.
`ADD:` `FIX:` `REF:` 에는 `Contracts:` 트레일러가, **모든 커밋**에는 `Signed-off-by:` 가 필수다.

### 모든 역할이 지키는 것
- 시험기관·KISA 답변, 표준의 판·연도, GVI 조항을 기억으로 채우지 않는다 (R10)
- "KCMVP 검증됨/인증됨" 이라고 쓰지 않는다
- 마지막 보고에 **"확인하지 못한 것"** 을 쓴다

# 커밋 규약

`.githooks/commit-msg` 가 기계적으로 강제한다.

---

## 형식

```
<TYPE>[(<범위>)]: <한 줄 요약>

<본문: 왜 이렇게 했는지. 무엇을 했는지는 diff 가 말한다>

Contracts: <건드린 계약 | none>
Invariants: <건드린 불변식 | none>
Milestone: <M0~M6>
Review: <리뷰 결과 | n/a>
Refs: <ADR·이슈·계획서 절>
Signed-off-by: <이름> <<이메일>>
```

범위(선택): `core` `module` `ffi` `oracle` `ct` `fuzz` `vectors` `build` `kcmvp` `agents`

---

## 타입

| 타입 | 쓰는 경우 | 쓰지 않는 경우 |
|---|---|---|
| **`ADD:`** | 새 기능, 새 파일, 새 모듈, 새 API | 테스트만 → `TEST:` / 문서만 → `DOCS:` |
| **`FIX:`** | **버그 수정** | 동작이 바뀌지 않는 정리 → `REF:` |
| **`REF:`** | **리팩터링 — 동작 불변** | 동작이 바뀌면 `FIX:` 또는 `ADD:` |
| **`UPT:`** | **의존성·툴체인 업데이트** | 코드 변경이 주면 그쪽 타입 |
| **`DEL:`** | 기능·파일·API 제거 | 리팩터링 중의 부수적 삭제 → `REF:` |
| **`TEST:`** | 테스트·하네스·정답 벡터·실패 코퍼스·퍼징 | — |
| **`DOCS:`** | 문서, 주석, ADR, KCMVP 제출물 초안, provenance | — |

### jamulsoe 특수 사례

| 작업 | 타입 | 비고 |
|---|---|---|
| `jamulsoe-oracle` / `jamulsoe-ct` 작업 | **`TEST:`** | 경계 밖 하네스 |
| 정답 벡터·실패 코퍼스 추가 | **`TEST:`** | 추가만 가능 |
| 계약 레지스트리 항목 연결 | **`TEST:`** | |
| ADR 작성 | **`DOCS:`** | |
| `rust-toolchain.toml` 변경 | **`UPT:`** | 사람 승인, 별도 커밋, CT 재검사 |
| `exports.txt`·헤더 변경 | **`ADD:`/`DEL:`** | 사람 승인, 별도 커밋, 본문에 보안정책문서 영향 |
| 성능 개선 (동작 불변) | **`REF:`** | `ct-auditor` 필수 |
| `.agents/` 변경 + 생성물 | **`DOCS(agents):`** | 원천과 생성물을 같은 커밋에 |

### `FIX:` vs `REF:`

> **"이 변경 없이도 기존 테스트가 전부 통과하는가?"**
> 통과한다 → `REF:` / 실패하는 테스트가 있다 → `FIX:` (재현 테스트 필수)

---

## 트레일러

| 트레일러 | 필수 | 내용 |
|---|---|---|
| `Signed-off-by:` | **모든 커밋** | DCO. `git commit -s`. 형상관리문서의 작성자 추적 근거 |
| `Contracts:` | `ADD:` `FIX:` `REF:` | `C2, C4` 또는 `none` |
| `Invariants:` | 선택 | `I1` 등 |
| `Milestone:` | 권장 | `M0`~`M6` |
| `Review:` | 머지 커밋에 권장 | `P1 0 / P2 2 해소 / P3 3 유예` |
| `Refs:` | 선택 | ADR, 이슈, 계획서 절 |
| `Approved-by:` | 보호 경로 변경 시 | `JMS_APPROVED_BY` 와 같은 이름 (`.agents/APPROVAL.md`) |

> `Contracts: none` 이라고 쓰기 전에 한 번 더 생각한다. `contract-auditor` 가 검증한다.

---

## 예시

```
TEST(vectors): RFC 5794 ARIA 블록 벡터와 러너 추가

M1 의 첫 하네스. 러너는 아직 스텁 구현에 대해 기대값 불일치로 실패한다.
원본은 RFC 5794 Appendix A 그대로이고 SOURCES.md 에 SHA-256 을 남겼다.

Milestone: M1
Refs: docs/PLAN.md §ARIA
Signed-off-by: devgyurak <dev@devgyurak.com>
```

```
FIX(core): GCM open 이 태그 불일치에서도 키스트림을 계산하던 문제

출력에는 쓰지 않았지만 CSP-04 를 불필요하게 만들고 지우지 않은 채 반환했다.
태그 비교 후에만 CTR 을 돌리도록 순서를 고치고 반환 전 제로화를 추가했다.

재현 테스트: crates/jamulsoe-core/tests/gcm_open.rs
  given_bad_tag_when_open_then_no_keystream_generated

Contracts: C2, C4
Invariants: I2, I4
Milestone: M1
Review: P1 1 해소 / P2 0 / P3 1 유예
Signed-off-by: devgyurak <dev@devgyurak.com>
```

---

## 금지

- ❌ 요약이 없는 커밋, 여러 관심사를 한 커밋에
- ❌ `FIX:` 인데 재현 테스트가 없음 / `REF:` 인데 동작이 바뀜
- ❌ `Signed-off-by:` 없음
- ❌ 보호 경로 변경을 다른 변경과 섞기 — **반드시 별도 커밋**

---
description: jamulsoe 절대 규칙 — 모든 작업에 적용
alwaysApply: true
order: 000
---

# jamulsoe 핵심 규약

**단일 원천은 `AGENTS.md` 다.** 작업 전에 반드시 읽는다. 이 파일은 요약일 뿐이다.

## 절대 규칙 (위반 시 작업 중단)

1. **R1 하네스 먼저** — 정답 벡터·실패 케이스·오라클로 된 실패하는 테스트 없이 구현하지 않는다
2. **R2 계약 C1~C5 가 상위** — `docs/CONTRACTS.md`
3. **R3 구현자는 자기 코드를 리뷰하지 않는다** — 세션을 나눈다
4. **R4 자기를 판정하는 것을 고치지 않는다** — 계약·계획서·공개 인터페이스·기준선·`scripts/**`·`AGENTS.md`·`.agents/**`·
   도구 훅 설정·CI 는 사람만, 벡터·코퍼스·감사는 추가만, 레지스트리는 테스트 연결만, ADR 은 제안만.
   정의: `scripts/hooks/protected.tsv` · 설명: `.agents/APPROVAL.md` · **셸로 우회하지 않는다**
5. **R5 테스트 없는 머지 없음** — 벡터 + 실패 케이스 + 차등 + 상수 시간 + 커버리지 + 뮤턴트 0
6. **R6 `unsafe` 는 `jamulsoe-ffi` 에만** — `// SAFETY:` + Miri + ASan
7. **R7 비밀값으로 분기·인덱싱하지 않는다** (C1)
8. **R8 경계 안을 키우지 않는다** — 외부 의존 0, 알고리즘당 경로 1, 비승인 알고리즘 없음, 패닉 없음
9. **R9 외부 코드를 옮기지 않는다** — 참고는 `docs/provenance.md` 에 기록
10. **R10 추측하지 않는다** — 표준·GVI·시험기관 해석은 `docs/kcmvp/inquiry-drafts.md` 질문 초안으로. 답을 지어내지 않는다

## 작업 루프

① SPEC → (①′ 사람 방향 확인) → ② HARNESS → ③ IMPL → ④ VERIFY → ⑤ REVIEW → ⑥ RECORD
상세: `.agents/WORKFLOW.md` · 역할: `.agents/ROLES.md`

**가장 흔한 실패는 ②를 건너뛰고 ③으로 가는 것이다.**

## 마일스톤

현재 위치: `docs/ROADMAP-STATUS.md`. **G1(경계·API 동결) 전에는 M0~M1 만 한다.**

## 게이트

```
./scripts/verify.sh --fast   # 개발 중, pre-push
./scripts/verify.sh          # 머지 전 (최종 판정은 CI, Linux x86_64)
```

"미적용"과 "실행 불가"는 통과가 아니다. 임계값을 낮춰서 통과시키지 않는다.

## 하지 말 것

- 테스트·정답 벡터를 고쳐서 통과시키기 → 구현을 고치거나 **멈춰서 묻는다**
- `exports.txt`·헤더를 맞춰 고쳐서 ABI 게이트 통과시키기
- `#[ignore]` / `#[allow(...)]` 를 근거 없이 추가
- 계획서에 없는 알고리즘·API·구현 경로를 "있으면 좋을 것 같아서" 추가
- "KCMVP 검증됨/인증됨" 표기

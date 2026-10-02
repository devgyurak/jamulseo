---
description: 테스트 규약 — GWT 네이밍, 정답 벡터, 실패 코퍼스
paths:
  - "tests/**"
  - "**/tests/**"
  - "fuzz/**"
globs:
  - "tests/**"
  - "**/tests/**"
  - "fuzz/**"
alwaysApply: false
order: 110
---

# 규칙: 테스트

적용: `tests/**`, `**/tests/**`, `fuzz/**`, `#[cfg(test)]` 블록 · 전문: `docs/TESTING.md`

## GWT 네이밍 — 기계적으로 강제됨

```
given_<초기 상태>_when_<행위>_then_<관측 가능한 기대>
```

`then_works` / `then_ok` / `then_success` 는 거부된다. `scripts/lint-gwt.sh` 가 pre-commit · CI · 편집 후 훅에서 검사한다.

## 정답 벡터 (`tests/vectors/`)

- **원본 그대로 새 파일로** 넣는다. 변환은 스크립트로, 스크립트도 커밋
- `tests/vectors/SOURCES.md` **끝에** 출처·판·확보 날짜·SHA-256 행을 붙인다
- 데이터 파일은 **새 파일 추가만** — 기존 파일에 붙이는 것도 판정기가 막는다 (레코드 중간 삽입으로 기대값을 바꿀 수 없게)
- 벡터가 틀렸다고 보이면 출처를 대고 멈춘다

## 실패 코퍼스 (`tests/negative/`)

- 퍼징·리뷰·버그에서 나온 재현 입력은 **즉시** 추가. "나중에"는 없다
- **새 파일 추가만 가능.** 수정·삭제는 사람만
- 각 항목은 기대 오류 코드 **와** 무변경(I1)을 확인한다 — 출력 버퍼를 센티널(예: `0xA5`)로 채우고 그대로인지 본다

## 가장 자주 틀리는 것

1. **assert 없는 테스트** — `scripts/lint-tests.sh` 가 잡는다
2. **테스트를 고쳐서 통과시키기** — 금지. 구현을 고치거나 **멈춰서 묻는다**
3. **② HARNESS 테스트 커밋을 초록으로 넘기기** — 테스트 커밋 시점에 실패해야 한다. main 에는 같은 PR 의 구현 커밋과 함께 초록으로 들어간다
4. **오류 코드만 보고 무변경을 안 봄** — I1 은 별개의 약속이다
5. **proptest 회귀 파일 미커밋** — `proptest-regressions/` 는 반드시 커밋
6. **happy path 부터** — 경계값·실패 경로를 먼저
7. **계약 테스트를 레지스트리에 안 올림** — `tests/contracts/registry.json` 의 해당 단계에 테스트 이름까지
8. **`#[ignore]` 테스트를 계약에 연결** — 실행되지 않는 테스트는 증거가 아니다 (`contract-check` 가 막는다)

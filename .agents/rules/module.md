---
description: 모듈 계층 규칙 — C3 상태·자가시험, C4 제로화
paths:
  - "crates/jamulsoe-module/**"
globs:
  - "crates/jamulsoe-module/**"
alwaysApply: false
order: 210
---

# 규칙: 모듈 계층 (`jamulsoe-module`)

적용: `crates/jamulsoe-module/**` · 전문: `docs/CONTRACTS.md#c3`, `#c4`, 계획서 §C ABI 설계 > 규칙

> 🚧 **G1 이전**: 공개 동작(상태 전이 규칙, 서비스 표)을 확정하지 않는다. 하네스와 내부 설계 ADR 까지만.

## 절대 규칙

1. **"read lock → 상태 확인 → 연산"** 순서. 상태를 먼저 읽고 lock 을 나중에 잡으면 자가시험 실패 직후에도 출력이 나간다 (I3)
2. **상태 표시 atomic 과 서비스 직렬화 RwLock 은 분리**한다. `jms_status` 는 atomic 만 (lock 없이)
3. `init`·`selftest` 는 **write lock**. init 은 미초기화 → 자가시험 → 승인 동작|오류. 승인 동작에서 init 은 멱등 OK, 오류에서 `STATE`
4. **자가시험·무결성 시험은 공개 서비스를 재진입하지 않는다.** core 내부 함수를 직접 부른다
5. **오류 → 자가시험 경로 없음.** 복구는 재적재뿐
6. 상태별 허용 서비스: 암호 서비스는 승인 동작에서만. 상태·버전 조회, 제로화, 해제는 모든 상태
7. **실패 주입은 `fault-injection` feature 뒤에만.** 기본 빌드에 주입 코드가 없음을 테스트로 고정
8. 메모리 순서(`Ordering::*`)마다 "왜 이것인가" 주석

## 열린 질문 (답 전에 정하지 않는다 — `docs/kcmvp/inquiries.md`)

- 오류 전이 시 기존 AEAD 컨텍스트 CSP 즉시 제로화 필요 여부 → 필요하면 컨텍스트 레지스트리 (구조 변경)
- 무결성 태그 위치(별도 파일 vs 내장)와 고정 HMAC 키의 CSP 해당 여부
- 알고리즘 KAT 의 자가시험 분류(조건부)

## 필수 테스트

상태 전이 전 경로, 자가시험 실패 주입 → 오류 상태 → 허용 서비스만 동작, 동시 init, 자가시험 중 서비스 대기.

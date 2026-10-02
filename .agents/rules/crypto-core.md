---
description: 알고리즘 코어 규칙 — C1 상수 시간, C4 CSP, 단일 경로
paths:
  - "crates/jamulsoe-core/**"
globs:
  - "crates/jamulsoe-core/**"
alwaysApply: false
order: 200
---

# 규칙: 알고리즘 코어 (`jamulsoe-core`)

적용: `crates/jamulsoe-core/**` · 전문: `docs/CONTRACTS.md#c1`, `#c4`, 계획서 §알고리즘 구현 계획

## 크레이트 성질 (`scripts/lint-boundary.sh` 가 강제)

`#![no_std]` · `#![forbid(unsafe_code)]` · 힙 없음(`alloc` 금지) · `[dependencies]` 비어 있음.

## 상수 시간 — 비밀값 목록

키, 라운드 키, W0~W3, GHASH 키 H, 키스트림·카운터 블록, 평문, 계산된 태그(비교 전), HMAC 키·정규화 값·ipad/opad 상태.
**공개값**: 길이, IV, AAD, 암호문, 입력 태그. 공개값으로는 분기해도 된다.

1. **S-box 는 회로로.** 테이블 조회 금지. S1(=AES S-box)·S2 는 GF(2⁸) 역원 회로를 공유하는 비트슬라이스로, 4블록 단위
2. **GHASH 는 정수 곱셈 캐리리스(ctmul64 방식).** 4·8비트 테이블 금지. 64비트 곱셈 상수 시간 가정은 문서에 명시돼 있어야 한다
3. **태그 비교는 전 바이트 누적 후 한 번 판정.** 조기 반환·`==`·`bool` 단락 평가 금지
4. **value barrier** 를 비밀값 마스크·선택에 쓴다. 컴파일러가 분기를 되살릴 수 있다
5. 테스트·디버그 출력에 비밀값을 찍지 않는다

## 단일 경로

- 단일 블록도 4블록 비트슬라이스 코어를 거친다. 두 번째 구현(테이블·SIMD·하드웨어 가속)을 두지 않는다
- 참조 구현은 `jamulsoe-oracle`(경계 밖)에만 있다

## GCM

- IV 96비트·태그 128비트만. 다른 길이는 타입으로 존재하지 않는다 (`[u8; 12]`, `[u8; 16]`)
- open: **태그 계산 → 상수 시간 비교 → 통과 시에만 CTR 복호화**. 실패 시 출력에 한 바이트도 쓰지 않는다 (I2)
- in-place 는 `&mut [u8]` 하나를 받는 별도 함수
- 길이 상한(`MAX_TEXT_BYTES`, `MAX_AAD_BYTES`)은 상수로, 진입점에서 먼저 검사. 값은 G1 에서 확정 — 그 전에는 SP 800-38D 한도를 쓰고 `// G1:` 주석

## CSP (C4)

- 키 스케줄은 `&mut` 출력 인자로. 값 반환 금지. W0~W3 는 반환 전 제로화
- 비밀값 타입은 `Copy`/`Clone`/`Debug` 없음, `Drop` 에서 제로화
- 새 비밀값이 생기면 `docs/CONTRACTS.md` CSP 인벤토리에 있는지 확인. 없으면 **멈추고 묻는다**

## 노출

원시 블록 연산(ECB)은 C ABI 로 나가지 않는다. 하네스 접근 방식은 G1 질문 답변 후 정한다.

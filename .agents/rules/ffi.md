---
description: C ABI 규칙 — C2 계약, unsafe, 공개 인터페이스
paths:
  - "crates/jamulsoe-ffi/**"
  - "include/**"
  - "exports.txt"
  - "bindings/**"
globs:
  - "crates/jamulsoe-ffi/**"
  - "include/**"
  - "exports.txt"
  - "bindings/**"
alwaysApply: false
order: 220
---

# 규칙: C ABI (`jamulsoe-ffi`)

적용: `crates/jamulsoe-ffi/**`, `include/**`, `exports.txt`, `bindings/**` · 전문: `docs/CONTRACTS.md#c2`, 계획서 §구현 체크리스트

> 🚧 **G1 이전**: 공개 API를 확정하지 않는다. `include/jamulsoe.h`·`exports.txt` 는 **사람만** 고친다.

## 진입점의 순서 — 이것만은 외운다

```
1. 필수 포인터 NULL 검사               → PARAM
2. (ptr, len) 쌍: len > 0 && NULL      → PARAM
3. 길이 상한·누적 길이 (checked_*)       → PARAM
4. 겹침 (addr() 정수 [start,end))       → PARAM
5. 출력 용량                           → BUFFER
6. 컨텍스트 상태                        → CTX_STATE
7. ─── 여기까지 통과해야 슬라이스·참조를 만든다 ───
8. module 서비스 호출 (lock → 상태 → 연산) → STATE / AUTH
9. 성공 시에만 출력 기록
```

## 자주 틀리는 것

1. **슬라이스를 만든 뒤 겹침 검사** — 이미 UB 일 수 있다. 검사 먼저
2. **`offset_from`·포인터 뺄셈** — 다른 allocation 이면 UB. `ptr.addr()` 정수만 비교
3. **NULL 로 `from_raw_parts`** — 길이 0 이어도 UB. 빈 슬라이스 상수를 쓴다
4. **`Box::new`** — 할당 실패를 `NOMEM` 으로 못 바꾼다. `std::alloc::alloc` + NULL 검사
5. **스택에서 완성한 컨텍스트를 `ptr::write`** — 라운드 키 사본이 스택에 남는다 (C4). 할당 먼저, 최종 위치에 직접 계산
6. **생성 실패 시 `*out` 에 쓰레기** — 진입 즉시 `*out = NULL`
7. **free 순서** — `zeroize → drop 필요한 필드 → 같은 Layout dealloc`. `free(NULL)` 무동작
8. **ffi 가 core 를 직접 호출** — 상태 검사 우회. ffi 는 module 만 의존한다
9. **`// SAFETY:` 가 실제 검사와 안 맞음** — 어느 단계(1~6)가 이 블록을 정당화하는지 번호로 적는다

## 공개 인터페이스

- export 는 `#[no_mangle] pub extern "C"` 로 명시한 것뿐. `exports.txt` 와 같아야 한다 (게이트 12)
- 헤더는 cbindgen 생성물. 손으로 고치지 않는다
- `crate-type = ["cdylib"]`. staticlib 금지
- `bindings/` 는 경계 밖 예제다. 바인딩이 계약을 다시 구현하지 않는다 (상수는 헤더에서)

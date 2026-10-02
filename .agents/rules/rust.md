---
description: Rust 규약 — 모든 .rs 파일
paths:
  - "**/*.rs"
globs:
  - "**/*.rs"
alwaysApply: false
order: 100
---

# 규칙: 모든 Rust 파일

적용: `**/*.rs` · 전문: `docs/RUST-GUIDE.md`

## 이 저장소에서 가장 자주 틀리는 것

1. **비밀값 분기·인덱싱 (C1, R7)** — `if key[i] == ..`, `match` on 비밀값, `TABLE[secret as usize]`,
   슬라이스 `==` 로 태그 비교, 첫 불일치에서 `return`. 상수 시간 헬퍼(`ct::eq`, 마스크 선택, value barrier)를 쓴다
2. **패닉 경로** — 경계 크레이트(core·module·ffi)에서 `unwrap`/`expect`/`panic!`/`unreachable!`/`todo!`/
   범위 밖 인덱싱. 릴리스는 `panic = "abort"` 라 **호스트 프로세스가 죽는다**. `get()`·`checked_*`·오류 반환
3. **산술 오버플로·축소 변환** — 길이×8, 블록 수, offset+len 은 `checked_*`. `u64 as usize`, `usize as u32` 금지 → `try_from`
4. **비밀값 타입의 `Copy`/`Clone`/`Debug`** — 복제와 로그 누출의 통로. `Drop` 에서 `write_volatile` + `compiler_fence`
5. **값 반환 사본 (C4)** — 라운드 키·H·중간값을 값으로 돌려주지 않는다. `&mut` 출력 인자
6. **`unsafe`** — `jamulsoe-ffi` 밖에서는 컴파일 오류(`forbid`)여야 한다. ffi 안에서는 블록마다 `// SAFETY:`
7. **외부 크레이트** — 경계 크레이트에 `[dependencies]` 추가 금지 (R8). `thiserror` 도 쓰지 않는다

## 에러

core·module 은 직접 정의한 `enum` 오류(`#[non_exhaustive]` 아님 — 전수 매칭으로 코드 변환 누락을 막는다).
ffi 가 `JMS_*` 코드로 바꾼다. 오류 코드 집합은 계획서 표가 전부다. 새 코드를 만들지 않는다.

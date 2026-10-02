# Rust 규약

모든 경계 크레이트(`jamulsoe-core`·`-module`·`-ffi`)에 적용한다. 경계 밖 크레이트(`-oracle`·`-ct`, 테스트, 퍼징)는
§2·§5 를 완화할 수 있지만 §1(비밀값)·§8(문서)은 지킨다.

---

## 1. 비밀값 (C1, C4)

- 비밀값으로 분기(`if`·`match`·`while`·`?`·조기 `return`)·인덱싱·나눗셈·나머지 하지 않는다
- 비교는 상수 시간 헬퍼로. 슬라이스 `==`, `bool` 단락 평가(`&&`, `||`) 금지
- 선택은 마스크로 (`(a & m) | (b & !m)`), 마스크 생성은 value barrier 를 거친다
- 비밀값 타입은 `Copy`/`Clone`/`Debug`/`Display` 를 구현하지 않는다
- `Drop` 에서 `core::ptr::write_volatile` 로 덮고 `core::sync::atomic::compiler_fence(SeqCst)`
- 비밀값을 값으로 반환하지 않는다. `&mut` 출력 인자
- 비밀값을 로그·패닉 메시지·오류 값에 넣지 않는다

## 2. 패닉

- 경계 크레이트에 `unwrap`·`expect`·`panic!`·`unreachable!`·`todo!`·`unimplemented!`·`assert!`(debug 제외) 금지
- 슬라이스 인덱싱 `a[i]` 대신 고정 크기 배열과 반복자, 또는 `get()` + 오류. 컴파일러가 경계 검사를 증명할 수 있는 고정 크기 배열 인덱싱은 허용
- 정수 나눗셈은 0 이 불가능함을 타입으로 보장할 때만
- 릴리스는 `panic = "abort"` — 패닉은 **호스트 프로세스 종료**다

## 3. 산술

- 길이×8, 블록 수, offset+len, 누적 길이는 `checked_*`. 실패는 `PARAM`
- `as` 축소 변환 금지 (`u64 as usize`, `usize as u32`). `try_from` 을 쓴다. 확장(`u32 as u64`)은 허용
- 래핑이 의도된 암호 연산(`wrapping_add` 등)은 명시적으로 `wrapping_*`

## 4. `unsafe` (R6)

- `jamulsoe-ffi` 에만. core·module 은 `#![forbid(unsafe_code)]`
- 모든 `unsafe` 블록 위에 `// SAFETY:` — 어떤 사전 검사(`.agents/rules/ffi.md` 의 단계 번호)와 어떤 호출자 계약이 이 블록을 정당화하는가
- 블록은 최소로. 한 블록에 한 가지 위험한 연산
- 포인터 산술(`offset_from`, `sub_ptr`) 금지. 주소 비교는 `addr()` 정수로
- Miri 와 ASan 을 통과해야 한다

## 5. 의존성 (R8)

- 경계 크레이트의 `[dependencies]`·`[build-dependencies]` 는 경계 크레이트 사이의 path 의존만
- `thiserror`·`zeroize`·`subtle` 같은 "작은" 크레이트도 쓰지 않는다 — 경계 안 코드는 전부 제출 소스다
- 테스트용 크레이트(proptest, openssl 바인딩)는 `dev-dependencies` 에만

## 6. 오류

- core·module: 직접 정의한 `enum`. `#[non_exhaustive]` 를 쓰지 않는다 (ffi 의 전수 매칭으로 변환 누락을 막는다)
- ffi: `enum` → `JMS_*` `c_int` 변환을 **한 곳**에서. 오류 코드 집합은 계획서 표가 전부

## 7. 동시성 (module)

- 상태 표시 `AtomicU8` 과 서비스 직렬화 `RwLock` 을 분리
- 모든 `Ordering` 에 "왜" 주석
- lock poisoning: `panic = "abort"` 라 발생하지 않지만, `PoisonError` 를 `unwrap` 하지 않는다 (테스트 프로파일은 unwind)

## 8. 문서

- 경계 크레이트의 `pub` 항목은 `# Errors`, 비밀값을 다루면 `# Security`, unsafe 함수는 `# Safety`
- 불변식은 `# Invariants` 절에. 계약 조항 ID(예: `C2-10`)를 적는다
- `#![warn(missing_docs)]`

## 9. 리뷰 체크리스트 (`rust-reviewer`)

- [ ] 경계 안에 패닉 경로가 없다 (§2)
- [ ] 길이 산술이 전부 checked, `as` 축소가 없다 (§3)
- [ ] `unsafe` 는 ffi 에만, 블록마다 `// SAFETY:` 가 실제 검사와 맞는다 (§4)
- [ ] 비밀값 타입에 `Copy`/`Clone`/`Debug` 가 없고 `Drop` 제로화가 있다 (§1)
- [ ] 비밀값 의존 분기·인덱싱·`==` 가 소스에 없다 (깊은 검토는 `ct-auditor`)
- [ ] 경계 크레이트에 외부 의존이 없고 의존 방향이 맞다 (§5)
- [ ] 오류 변환이 한 곳에서 전수 매칭된다 (§6)
- [ ] `Ordering` 마다 근거 주석이 있다 (§7)
- [ ] `pub` 문서에 `# Errors`·`# Security`·`# Safety` 가 있다 (§8)
- [ ] 테스트가 GWT 이고, 오류 테스트가 무변경을 함께 본다 (`docs/TESTING.md`)
- [ ] `#[ignore]`·`#[allow]` 에 근거 주석이 있다

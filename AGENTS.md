# AGENTS.md — jamulsoe 에이전트 작업 규약 (단일 원천)

> 이 파일이 **모든 코딩 에이전트의 단일 원천(single source of truth)** 이다.
> Claude Code(`CLAUDE.md`), Codex, opencode, Cursor(`.cursor/rules/`), pi(`.pi/`)의 설정은
> 전부 이 파일을 가리키는 **얇은 어댑터**다. 규칙이 바뀌면 여기와 `.agents/` 를 고친다.
> 도구별 매핑은 `.agents/COMPATIBILITY.md`.

---

## 0. 프로젝트 한 줄 정의

**jamulsoe** = Rust로 구현하고 C ABI(`libjamulsoe.so` + `jamulsoe.h`)로 제공하는 오픈소스 국산 암호 모듈.
1차 목표는 **ARIA-GCM · SHA-256 · HMAC-SHA-256** 범위로 **KCMVP 보안등급 1** 검증을 받는 것이다.

- 운영환경(v1): Ubuntu 24.04 LTS, x86_64 **하나**
- 비목표(v1): DRBG·잡음원, 공개키·전자서명, TLS, 하드웨어 가속, Windows/macOS
- 라이선스: Apache-2.0, 기여는 DCO(`Signed-off-by:`) 필수
- 기획 원본: `docs/PLAN.md` — **2026-10-02 동결본**. 변경은 G1에서 시험기관 답변과 함께 사람이 반영한다
- 계약 전문: `docs/CONTRACTS.md` (C1~C5, I1~I5)

에이전트가 만드는 것은 **검증을 받을 코드와 그 증거**다. "동작한다"가 아니라
"시험기관과 제3자가 **확인할 수 있다**"가 완료 기준이다.

---

## 1. 절대 규칙 (위반 시 작업 중단)

| # | 규칙 | 근거 |
|---|---|---|
| R1 | **하네스가 먼저, 구현은 나중.** 정답 벡터·실패 케이스·오라클로 된 **실패하는 테스트** 없이 알고리즘·모듈·FFI 코드를 쓰지 않는다. 하네스와 구현은 **같은 PR** 에 두고 테스트 커밋(`TEST:`)이 구현 커밋보다 먼저 온다. `develop` 에는 초록만 들어간다 | 계획서 §테스트·검증 전략, `.agents/WORKFLOW.md` ② |
| R2 | **계약 C1~C5가 다른 모든 결정보다 상위.** 하위 설계가 충돌하면 계약이 이기고 하위 설계를 고친다 | `docs/CONTRACTS.md` |
| R3 | **구현한 에이전트는 자기 코드를 리뷰하지 않는다.** 리뷰는 반드시 새로 띄운 다른 에이전트가 한다 | `.agents/INDEPENDENCE.md` |
| R4 | **에이전트는 자기를 판정하는 것을 고칠 수 없다.** 계약·동결 계획서·공개 인터페이스·툴체인 기준선·`scripts/**`·에이전트 규약(`AGENTS.md`, `.agents/**`)·도구 훅 설정·CI 는 사람만, 정답 벡터·코퍼스·감사 기록은 추가만, 계약 레지스트리는 테스트 연결만, ADR 은 `제안` 만. 셸로 우회하지 않는다 | `scripts/hooks/protected.tsv`, `.agents/APPROVAL.md` |
| R5 | **테스트 없는 머지 없음.** 정답 벡터 + 실패 케이스 + 차등 비교 + 상수 시간 회귀 검사 + 커버리지 + 뮤턴트 0이 머지 조건 | `docs/TESTING.md` |
| R6 | **`unsafe`는 `jamulsoe-ffi` 에만.** `// SAFETY:` 근거 주석 + Miri + AddressSanitizer 통과 없이는 추가 금지. core·module 은 `#![forbid(unsafe_code)]` | 계약 C5 |
| R7 | **비밀값으로 분기·인덱싱하지 않는다.** 비밀값 의존 제어 흐름·메모리 주소·가변 지연 명령 금지. 비밀값 연산은 value barrier 헬퍼를 거친다 | 계약 C1 |
| R8 | **모듈 경계 안을 키우지 않는다.** 외부 크레이트 의존 0, 알고리즘당 구현 경로 1개, 비승인 알고리즘·하드웨어 가속 없음, 패닉 경로 없음 | 계약 C5 |
| R9 | **외부 코드를 옮기지 않는다.** KISA 참고 소스·비트슬라이스 회로·BearSSL 등은 설계 참고와 테스트 오라클로만 쓰고, 참고한 사실은 `docs/provenance.md` 에 기록한다 | 계획서 §기여·라이선스 |
| R10 | **추측하지 않는다.** 표준 원문·GVI·시험기관 해석이 필요한 것은 임의로 정하지 않는다. `docs/kcmvp/inquiry-drafts.md` 에 질문 초안으로 올리고 멈춘다. 답변 기록(`docs/kcmvp/inquiries.md`)은 사람만 쓴다. **시험기관 답변을 지어내지 않는다** | 계획서 §리스크와 열린 질문 |

---

## 2. 핵심 계약 C1~C5 (요약 — 전문은 `docs/CONTRACTS.md`)

코드를 바꾸기 전에 **"이 변경이 어떤 계약을 건드리는가"** 를 먼저 답한다.

| 계약 | 한 줄 | 깨지면 나타나는 증상 |
|---|---|---|
| **C1 상수 시간** | 검증 대상 CPU·고정 컴파일러에서 비밀값에 따라 제어 흐름·메모리 접근 주소가 달라지지 않고, 비밀값 의존 가변 지연 명령을 쓰지 않는다 | S-box 테이블 조회로 캐시 타이밍에 키 누출 / 태그 비교가 첫 불일치에서 조기 반환 |
| **C2 C ABI** | 오류 시 무변경, 필수 포인터·(포인터, 길이) 쌍·겹침·용량·길이 상한 규칙, 패닉 없음, export = `exports.txt` | `jms_sha256_final(ctx, NULL)` 이 컨텍스트를 final 시킴 / 부분 겹침을 받아 aliasing UB |
| **C3 모듈 상태·자가시험** | 암호 서비스는 **승인 동작 상태에서만**. "read lock → 상태 확인 → 연산" 순서. 자가시험은 공개 ABI를 재진입하지 않는다. 오류 상태는 재적재로만 복구 | 자가시험 실패 직후에도 다른 스레드의 seal 이 출력을 냄 |
| **C4 CSP 수명** | 비밀값은 인벤토리(CSP-01~05)에 있고, 사본을 만들지 않으며, 정해진 시점에 지워진다 | 스택에서 완성한 컨텍스트를 `ptr::write` 로 옮겨 라운드 키 사본이 스택에 남음 |
| **C5 모듈 경계·형상** | 경계 안은 core·module·ffi 세 크레이트뿐, 외부 의존 0, 툴체인 고정, 재현 빌드, 무결성 시험 | 두 러너의 `.so` SHA-256 불일치 / 경계 안에 `std` 밖 크레이트 유입 |

불변식 (전문은 `docs/CONTRACTS.md`):

- **I1 오류 시 무변경**: v1에서 발생 가능한 모든 오류에서 출력 버퍼와 컨텍스트는 바뀌지 않는다 (예외 2: `JMS_ERR_SELFTEST` 의 상태 전이, 생성 함수의 `*out = NULL`).
- **I2 인증 전 평문 없음**: `jms_aria_gcm_open` 은 태그를 먼저 상수 시간으로 검증하고, 통과할 때만 출력에 쓴다. in-place 에서도 실패 시 암호문이 그대로 남는다.
- **I3 상태 밖 출력 없음**: 승인 동작 상태가 아닌 동안 어떤 암호 서비스도 결과를 내지 않는다.
- **I4 CSP 사본 없음**: 인벤토리 밖의 비밀값 사본을 만들지 않고, 인벤토리의 파기 시점에 지운다 (레지스터·컴파일러 사본은 한계로 명시).
- **I5 인터페이스 고정**: `libjamulsoe.so` 의 `nm -D --defined-only` 결과 = `exports.txt`, `include/jamulsoe.h` = cbindgen 생성 결과.

---

## 3. 작업 루프 (모든 도구 공통)

```
  ① SPEC      계획서에 없는 결정만 ADR 초안   → spec-author
       ↓      (반박)                        → spec-redteam      [구현을 보지 않음]
  ①′ 방향 확인  ADR 의 방향을 사람이 확인       → 사람 (ADR 이 있을 때만)
       ↓
  ② HARNESS   실패하는 테스트·벡터·오라클     → harness-engineer + oracle-author  [서로 독립]
       ↓
  ③ IMPL      최소 구현                      → core / module / ffi -engineer
       ↓
  ④ VERIFY    게이트 실행                     → ./scripts/verify.sh
       ↓
  ⑤ REVIEW    교차 리뷰                      → rust-reviewer ∥ contract-auditor (∥ ct-auditor)  [③과 다른 에이전트]
       ↓
  ⑥ RECORD    ADR·제출물 초안·로드맵 갱신      → kcmvp-writer, 사람 승인
```

**이 순서를 건너뛰지 않는다.** 특히 ②를 건너뛰고 ③으로 가는 것이 가장 흔한 실패 모드다.
"정답 벡터 하나 맞추면 되는 간단한 변경"이라는 판단을 하지 않는다 —
암호 모듈의 사고는 정답 벡터가 아니라 **실패 경로·경계값·타이밍**에서 난다.

계획서가 이미 정한 것(알고리즘 구조, API 초안, 오류 코드, CSP 인벤토리 등)은 ①을 다시 하지 않는다.
상세 진입/종료 조건은 `.agents/WORKFLOW.md`. 리뷰 기준은 `docs/CODE-REVIEW.md`, 커밋 규약은 `docs/COMMIT.md`.

---

## 4. 명령어 (전부 `scripts/`의 같은 스크립트를 부른다)

| 목적 | 명령 | 게이트 |
|---|---|---|
| **게이트 자기 시험** | `./scripts/selftest-gates.sh` | 게이트가 위반을 실제로 잡는가 |
| 어댑터 정합성 | `./scripts/check-adapters.sh` | 생성물 ↔ `.agents/` 드리프트, symlink |
| 어댑터 생성 | `./scripts/sync-agents.sh` | `.agents/` → 도구별 파일 |
| 명세 전용 묶음 | `./scripts/spec-bundle.sh --for <역할>` | 오라클·레드팀용 (구현 격리) |
| 빠른 피드백 | `./scripts/check.sh` | fmt + clippy(-D warnings) + 빌드 |
| 경계 규약 | `./scripts/lint-boundary.sh` | 외부 의존 0, 의존 방향, `no_std`·`forbid(unsafe)`, `panic = "abort"`, cdylib |
| 단위·통합·벡터 | `./scripts/test.sh [crate]` | GWT 네이밍 포함 |
| 커버리지 | `./scripts/coverage.sh` | 전체 90% / core·module 95% |
| 계약 역방향 검사 | `./scripts/contract-check.sh` | 현재 마일스톤의 필수 계약 항목마다 실행되는 테스트가 있는가 |
| 결함 주입(뮤테이션) | `./scripts/mutants.sh` | 면제 목록 밖 **살아남은 뮤턴트 0** (PR 은 diff 범위, 종료 판정은 전체) |
| 상수 시간 | `./scripts/ct.sh --ctgrind` / `--dudect` / `--asm` | ctgrind(CI 차단) / dudect(기준 장비, 마일스톤 종료) / 감사용 덤프 |
| 메모리 안전 | `./scripts/memsafety.sh` | Miri + C 하네스 AddressSanitizer |
| ABI·심볼 | `./scripts/abi-check.sh` | cbindgen diff, `nm -D` ↔ `exports.txt`, C 예제 |
| 퍼징 스모크 | `./scripts/fuzz.sh` | FFI 경계·GCM open |
| 재현 빌드 | `./scripts/repro.sh` | 두 번 빌드한 `.so` SHA-256 일치 |
| **전체 게이트** | `./scripts/verify.sh` | 위 전부 (머지 조건) |

> 에이전트는 **`cargo` 를 직접 불러 판정하지 말고 이 스크립트를 쓴다.**
> 스크립트가 플래그·환경변수·임계값을 일관되게 관리하고, CI와 동일한 경로를 보장한다.
> 일부 게이트(상수 시간·ABI·ASan·재현 빌드)는 **검증 대상 환경(Linux x86_64)에서만 판정**한다.
> 다른 플랫폼에서는 "실행 불가"로 표시되며 **통과로 세지 않는다** (`.agents/WORKFLOW.md` ④).

---

## 5. 아키텍처 요약

```
                ┌──────────────── 모듈 경계 (libjamulsoe.so) ────────────────┐
  애플리케이션 ──► │ jamulsoe-ffi ──► jamulsoe-module ──► jamulsoe-core        │
  (C ABI만 호출)  │  C ABI·unsafe     상태머신·자가시험      no_std 알고리즘      │
                │  할당·포인터 검사   무결성 시험·제로화     ARIA·GCM·SHA·HMAC    │
                └───────────────────────────────────────────────────────────┘
  경계 밖: jamulsoe-oracle(참조 모델) · jamulsoe-ct(상수 시간 하네스) · tests/ · fuzz/
          · bindings/ · tools/integrity/
```

**의존 방향 규칙** (`scripts/lint-boundary.sh` 가 강제)
- `jamulsoe-core` 는 아무것도 의존하지 않는다 (`#![no_std]`, 힙 없음, `forbid(unsafe_code)`).
- `jamulsoe-module` 은 `core` 만, `jamulsoe-ffi` 는 `module` 만 의존한다.
  **ffi 가 core 를 직접 부르지 않는다** — 그러면 상태 검사(C3)를 우회하는 경로가 생긴다.
- 경계 밖 크레이트는 경계 크레이트의 `[dependencies]` 에 들어가지 않는다 (`dev-dependencies` 만).
- `jamulsoe-oracle` 은 경계 크레이트를 의존하지 않는다 (독립성의 마지막 그물).

---

## 6. Rust 규약 (전문: `docs/RUST-GUIDE.md`)

- **에러**: 외부 의존 0이므로 `thiserror` 를 쓰지 않는다. core·module 은 직접 정의한 `enum` 오류, ffi 가 `JMS_*` 코드로 바꾼다.
- **패닉**: 경계 안 코드에 `unwrap`/`expect`/`panic!`/범위 밖 인덱싱 경로를 두지 않는다. 릴리스는 `panic = "abort"` 라 패닉은 **호스트 프로세스 종료**다.
- **산술**: 길이×8, 블록 수, offset+len 은 전부 `checked_*`. `as` 축소 변환 금지 (`try_from`).
- **비밀값 타입**: `Copy`/`Clone`/`Debug` 를 구현하지 않는다. `Drop` 에서 `write_volatile` + `compiler_fence`.
- **가시성**: `pub(crate)` 가 기본. 경계 크레이트의 `pub` 은 문서(`# Errors`, `# Security`) 의무.
- **의존성**: 경계 크레이트에 외부 크레이트 추가 금지(R8). 경계 밖 `dev-dependencies` 추가는 `ask` 권한 + 사유.

---

## 7. 테스트 규약 (전문: `docs/TESTING.md`)

### 7.1 GWT 네이밍 — 강제됨

모든 테스트 함수 이름은 **`given_<상태>_when_<행위>_then_<기대>`** 형태다.
`scripts/lint-gwt.sh` 가 pre-commit · CI · 편집 후 훅에서 검사한다.

```rust
#[test]
fn given_tampered_aad_bit_when_open_in_place_then_auth_error_and_ciphertext_unchanged() { ... }
```

### 7.2 테스트 종류와 위치

| 종류 | 위치 | 대상 |
|---|---|---|
| 단위 | `crates/*/src/**` 의 `#[cfg(test)]` | 내부 함수, 비트슬라이스 회로, GHASH 곱셈 |
| 정답 벡터 | `tests/vectors/` (데이터) + 각 크레이트 `tests/` (러너) | KISA·RFC 5794·NIST CAVP·RFC 4231 |
| 차등 | `crates/*/tests/differential*.rs` | OpenSSL, `jamulsoe-oracle`, proptest |
| 실패 케이스 | `tests/negative/` (코퍼스) + `crates/jamulsoe-ffi/tests/` | C2 전 항목, I1·I2 |
| 계약 역방향 | `tests/contracts/registry.json` | 계약 조항 ↔ 테스트 연결 |
| 상수 시간 | `crates/jamulsoe-ct/` | S-box, GHASH, 태그 비교, HMAC 키 처리 |
| 퍼징 | `fuzz/` | FFI 경계, GCM open |
| 실패 주입 | `fault-injection` feature (검증 빌드 제외) | 자가시험·무결성·할당 실패 |
| C 하네스 | `tests/c/` | ABI 스모크, ASan |

### 7.3 커버리지와 뮤턴트

- 워크스페이스 라인 커버리지 **90%**, `jamulsoe-core`·`jamulsoe-module` **95%** (`scripts/_common.sh`).
- 커버리지는 필요조건일 뿐이다. **살아남은 뮤턴트 0** 이어야 테스트가 일한 것이다.
- assert 없는 테스트를 쓰지 않는다 (`scripts/lint-tests.sh`).

---

## 8. 로드맵 — 현재 위치를 항상 확인

```
M0  기반: 워크스페이스·툴체인·CI·하네스(벡터 러너, 오라클 골격, 상수 시간 하네스)   ← 지금
M1  알고리즘 코어: ARIA · GCM · SHA-256 · HMAC (jamulsoe-core)
G1  ── 경계·API 동결 게이트 (시험기관 답변 반영, 사람 결정) ──
M2  모듈: 상태머신 · 자가시험 · 무결성 시험 · CSP 제로화
M3  C ABI: jamulsoe-ffi · cbindgen 헤더 · exports.txt · 바인딩 예제
M4  검증 강화·공개: 퍼징 · Miri/ASan · 재현 빌드 → v0.1
M5  KCMVP 제출물: 설계서·보안정책문서·형상관리 · 구현적합성 사전 시험
G2  ── 시험 신청 게이트 (사람 결정) ──
M6  시험 대응 (kcmvp/v1 동결)
```

> M2~M5 의 내용은 계획서 로드맵 그림(원본에만 있음)을 본문에서 추정한 것이다. `docs/ROADMAP-STATUS.md` 참고.

현재 단계는 `docs/ROADMAP-STATUS.md` 와 `scripts/_common.sh` 의 `CURRENT_MILESTONE`.
**G1 전에는 M0~M1만 한다.** 모듈 상태머신·C ABI 를 "미리" 확정하지 않는다 —
경계와 API는 시험기관 답변에 따라 바뀐다.

---

## 9. 에이전트가 하지 말아야 할 것

- ❌ 테스트를 통과시키려고 테스트나 정답 벡터를 고치기 (구현을 고쳐라. 벡터가 틀렸다고 판단하면 출처를 대고 사람에게 물어라)
- ❌ `#[ignore]`, `#[allow(...)]` 를 근거 주석 없이 추가
- ❌ 커버리지·dudect 임계값, clippy 설정을 낮춰서 게이트 통과
- ❌ `exports.txt` 에 심볼을 추가해 ABI 검사를 통과시키기
- ❌ 보호 경로(`.agents/APPROVAL.md`) 무단 수정
- ❌ 비승인 알고리즘·"편의" API·두 번째 구현 경로(SIMD, 테이블 버전 등)를 경계 안에 추가
- ❌ 문서·주석·커밋에 "KCMVP 검증됨/인증됨" 표기 (검증서 번호가 나오기 전까지 사실이 아니다)
- ❌ 시험기관·KISA 답변, 표준의 판·연도, GVI 조항을 기억으로 채우기 (R10)
- ❌ 큰 변경을 한 번에. 한 PR = 한 관심사 = 리뷰 가능한 크기

---

## 10. 코드 리뷰 · 커밋

**전문은 각각 한 곳에만 있다. 여기 복제하지 않는다.**

| 주제 | 원본 | 한 줄 |
|---|---|---|
| 리뷰 심각도 | `docs/CODE-REVIEW.md` | `[P1]` 머지 차단 / `[P2]` 수정 또는 이슈+기한 / `[P3]` 선택 |
| 커밋 타입 | `docs/COMMIT.md` | `ADD:` `FIX:` `REF:` `UPT:` `DEL:` `TEST:` `DOCS:` + `Signed-off-by:` |
| 승인 경계 | `scripts/hooks/protected.tsv` (정의) · `.agents/APPROVAL.md` (설명) | 제안 ADR 은 가능, **채택 전환·보호 경로는 사람만**, 승인은 서명으로 |
| 역할 독립성 | `.agents/INDEPENDENCE.md` | 새 세션 + 명세 전용 묶음. 린트는 마지막 그물 |
| 브랜치 · 릴리스 | `docs/RELEASE.md` | 작업 브랜치 → `develop`(통합) PR / 릴리스는 `develop` → `main` PR 뒤 서명 태그 / `kcmvp/v1` 동결 |

놓치기 쉬운 것 셋:

- 심각도는 항상 대괄호 `[P1]`, 마일스톤은 `M1`. 표기가 다르므로 섞이지 않게 쓴다
- **`FIX:` vs `REF:`**: *"이 변경 없이도 기존 테스트가 전부 통과하는가?"* 통과 → `REF:` / 실패하는 테스트가 있었다 → `FIX:` (재현 테스트 필수)
- **모든 커밋에 `Signed-off-by:`** (DCO). `git commit -s` 로 만든다

보호 파일은 **반드시 별도 커밋**으로 분리한다. 훅이 섞인 커밋을 거부한다.
PR 본문에는 **"이 변경이 깨뜨릴 수 있는 계약과, 그것을 막는 테스트"** 섹션을 넣는다.

---

## 11. 도구별 어댑터 위치

| 도구 | 읽는 파일 | 비고 |
|---|---|---|
| Claude Code | `CLAUDE.md` → 이 파일 참조 / `.claude/` | 서브에이전트·슬래시 명령·훅 전부 지원 |
| Codex | `AGENTS.md` (이 파일) / `.codex/` | 서브에이전트 TOML · 프로필 |
| opencode | `AGENTS.md` / `.opencode/` | 에이전트·명령·플러그인(훅) |
| Cursor | `.cursor/rules/*.mdc` → 이 파일 참조 / `.cursor/hooks.json` | 규칙은 glob 기반 자동 첨부 |
| pi | `AGENTS.md` / `.pi/config.toml` | 제네릭 어댑터 — `.agents/COMPATIBILITY.md` 참고 |

**어느 도구를 쓰든 `./scripts/verify.sh` 가 진짜 게이트다.** 도구의 훅은 빠른 피드백일 뿐이다.

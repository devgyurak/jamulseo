# 테스트 전략

근거: `docs/PLAN.md §테스트·검증 전략`. 정답 벡터, 타 구현과의 차등 비교, 상수 시간 검사 세 가지가 CI 통과 조건의 축이다.
검증용 도구는 전부 `dev-dependencies` 나 별도 크레이트에 두어 **모듈 경계 밖**에 있게 한다.

---

## 1. 원칙

1. **하네스 먼저** (R1). 구현 전에 실패하는 테스트가 있어야 한다
2. **정답 벡터는 정상 경로 하나를 확인할 뿐이다.** 사고는 실패 경로·경계값·타이밍에서 난다
3. **오류를 기대하는 테스트는 오류 코드와 무변경(I1)을 함께 본다**
4. 테스트를 고쳐서 통과시키지 않는다. 정답 벡터·실패 코퍼스는 추가만 한다
5. 커버리지는 필요조건이다. 충분조건은 **살아남은 뮤턴트 0** 이다

---

## 2. GWT 네이밍

```
given_<초기 상태>_when_<행위>_then_<관측 가능한 기대>
```

- `then_works`·`then_ok`·`then_success` 는 거부된다
- 데이터 구동 테스트(벡터 러너)도 하나의 GWT 이름을 갖는다:
  `given_rfc5794_aria128_vectors_when_encrypt_block_then_all_match`
- 검사: `scripts/lint-gwt.sh` (pre-commit, CI, 편집 후 훅)

---

## 3. 테스트 종류

| 종류 | 위치 | 대상 | 마일스톤 |
|---|---|---|---|
| 단위 | `crates/*/src/**` 의 `#[cfg(test)]` | 비트슬라이스 회로, GHASH 곱셈, 키 스케줄 단계 | M1 |
| 정답 벡터 | `tests/vectors/` + `crates/jamulsoe-core/tests/vectors.rs` | KISA, RFC 5794, NIST CAVP SHA-256, RFC 4231 | M1 |
| 오라클 차등 | `crates/jamulsoe-core/tests/differential_oracle.rs` | `jamulsoe-oracle` 대비 무작위 입력 (proptest) | M1 |
| OpenSSL 차등 | `crates/jamulsoe-core/tests/differential_openssl.rs` | ARIA-GCM, SHA-256, HMAC | M1 |
| 상수 시간 | `crates/jamulsoe-ct/` | S-box, 라운드, 키 스케줄, GHASH, 태그 비교, HMAC 키 | M1 |
| 상태 전이 | `crates/jamulsoe-module/tests/` | C3 전 조항, 동시성 | M2 |
| 실패 주입 | `fault-injection` feature | KAT·무결성·할당 실패 → 오류 상태, 허용 서비스 | M2 |
| 실패 코퍼스 | `tests/negative/` + `crates/jamulsoe-ffi/tests/negative.rs` | C2 전 조항, I1·I2 | M3 |
| C 하네스 | `tests/c/` | ABI 스모크, ASan | M3 |
| 퍼징 | `fuzz/fuzz_targets/` | FFI 경계, GCM open, 차등 퍼징 | M3 |
| 메모리 안전 | Miri + ASan (`scripts/memsafety.sh`) | `jamulsoe-ffi` | M3 |
| ABI·심볼 | `scripts/abi-check.sh` | 헤더, export | M3 |
| 재현 빌드 | `scripts/repro.sh` | `libjamulsoe.so` | M4 |
| 구현적합성 사전 시험 | KCMVP 온라인 자가검증 시스템 (수동) | 검증 대상 알고리즘 전부 | M5 |

---

## 4. 정답 벡터 (`tests/vectors/`)

- **원본 그대로, 새 파일로** 저장한다. 형식 변환은 스크립트로 하고 스크립트도 커밋한다
- `tests/vectors/SOURCES.md` **끝에** 파일별로: 출처(URL·문서명·판), 확보일, 원본 SHA-256
- 데이터 파일은 **새 파일 추가만** — 기존 파일 끝에 붙이는 것도 막는다 (레코드 중간에 `CT = ...` 를 끼워 기대값을 바꿀 수 없게)
- 판·연도를 확인하지 못한 표준은 "확인 필요"로 남긴다 (R10)
- 러너의 실패 메시지는 벡터 파일·ID·기대값·실제값을 출력한다

## 5. 실패 케이스 코퍼스 (`tests/negative/`)

계획서가 요구하는 목록 — 전부 덮는다:

| 범주 | 예 | 기대 |
|---|---|---|
| 인증 실패 | 잘못된 태그, 1비트 바뀐 AAD·암호문·태그 | `AUTH` + 출력 무변경, in-place 암호문 보존 |
| 길이 경계 | 0, 1, 15/16/17, 상한, 상한+1, `SIZE_MAX`, SHA-256 누적 overflow | `PARAM` 또는 정상 + 무변경 |
| NULL 조합 | 필수 포인터 NULL, (NULL, 0), (NULL, >0), `free(NULL)` | `PARAM` / 정상 / 무동작 |
| 겹침 | 입력·출력, 출력·출력(`ct`·`tag`), in-place 의 IV·AAD·태그 겹침, 길이 0 구간 | `PARAM` / 허용 |
| 용량 | `ct_cap < pt_len`, `pt_cap < ct_len` | `BUFFER` + 무변경 |
| 컨텍스트 상태 | 인증 실패 후 재사용, zeroize 후 seal/open, final 후 update/final | 정상 / `CTX_STATE` |

- 각 항목은 출력 버퍼를 **센티널(`0xA5`)로 채우고** 호출 후 그대로인지 확인한다
- 퍼징·리뷰·버그에서 나온 재현 입력은 **즉시** 추가한다
- **새 파일 추가만 가능**

## 6. 계약 레지스트리 (`tests/contracts/registry.json`)

`docs/CONTRACTS.md` 의 조항 ID 마다 항목 하나. `scripts/contract-check.sh` 가 역방향으로 검사한다.

```json
{ "id": "C2-14", "stages": [
  { "milestone": "M1", "check": "test", "test": ["jamulsoe-core::given_bad_tag_when_open_in_place_then_auth_and_ct_unchanged"] },
  { "milestone": "M3", "check": "test", "test": [] } ] }
```

조항이 여러 마일스톤에 걸치면(`M1(core) · M3(ABI)`) 단계를 나눈다. 단계의 마일스톤 집합은 `docs/CONTRACTS.md` 의
마일스톤 열과 **같아야** 한다 — 레지스트리만 고쳐서 미룰 수 없다.

| `check` | 뜻 | 통과 조건 |
|---|---|---|
| `test` | 테스트가 막는다 | 실행 목록(`--list`)에 있고 **`#[ignore]` 가 아니다** (`--list --ignored` 로 뺀다) |
| `gate:<게이트>` | 게이트 스크립트가 강제한다 | 스크립트 존재 + `verify.sh` 에 등록 |
| `manual` | 사람·리뷰어가 확인한다 (어셈블리 감사 등) | `evidence` 가 `docs/audits/` 의 감사 파일, `verdict: pass`, 툴체인 = 현재, 감사 커밋 이후 `scope` 변경 없음 |
| `policy` | 절차 문서가 있다 (가장 약한 증거) | `evidence` 파일 존재 |

레지스트리 편집은 판정기가 제한한다: 항목 추가·`test` 이름 추가·`evidence` 갱신·`scope` 넓히기만 (`.agents/APPROVAL.md`).

**판정 모드**: 매 CI 는 **머지 판정** — 아직 연결되지 않은 단계는 "대기"이고, 이미 연결된 증거만 유효해야 한다
(SHA-256 만 넣는 첫 PR 이 ARIA 조항 때문에 막히지 않게). 마일스톤 종료(`verify.sh --milestone`)에서만 모든 단계를 요구한다.
manual 단계의 `scope` 는 감사가 덮어야 할 최소 범위, `attest: human` 은 사람 전용 경로(`docs/audits/attested/`)의 기록만 인정한다는 뜻이다.

## 7. 상수 시간 검사

- **회귀 탐지**이지 증명이 아니다 (계획서)
- `ctgrind` (C1-07, **CI 차단**): 비밀값을 Valgrind 미정의(undefined)로 표시하고 실행 — 미정의 값에 의존한 분기·주소가 있으면 오류. 결정적이라 공유 러너에서도 판정할 수 있다
- `dudect` (C1-08, **기준 장비·마일스톤 종료**): 고정 입력 vs 무작위 입력의 Welch t-검정, t 절댓값이 `DUDECT_T_MAX` 를 넘으면 실패.
  공유 CI 러너는 CPU 가 매번 달라 "검증 대상 CPU" 와 맞지 않고, 잡음 실패는 "재실행 금지" 와 충돌하므로 돌리지 않는다.
  `build/baseline.toml` 의 `ct_host_model` 장비에서 한 번 실행하고 `docs/audits/` 에 기록한다
- 어셈블리 감사 (C1-09, C4-03): `ct-auditor` 가 `ct.sh --asm` 덤프를 보고 `docs/audits/` 에 기록
- **M3 부터** 두 측정 모두 `--via-so` 로 검증 바이너리 `libjamulsoe.so` 를 C ABI 로 거치는 대상을 포함한다 — 하네스에 링크된 코어만 재면 검증 바이너리에 대한 증거가 아니다
- 하네스 자기 시험: **일부러 새는 대상**(테이블 S-box)을 하네스가 잡는지 확인한다
- 측정은 릴리스 프로파일·기준 CPU 플래그로. 툴체인이 바뀌면 전부 다시 돌리고 `ct-auditor` 가 어셈블리를 다시 본다

## 8. 커버리지

| 범위 | 하한 |
|---|---|
| 워크스페이스 (하네스·오라클 제외) | 90% |
| `jamulsoe-core`, `jamulsoe-module` | 95% |

임계값은 `scripts/_common.sh` 에만 있다. **낮추지 않는다.**

## 9. 변이 (뮤테이션)

`scripts/mutants.sh` (cargo-mutants). **면제 목록 밖의 missed = 0** 이 기준.

- PR: diff 에 걸친 뮤턴트만 (`--in-diff`). 마일스톤 종료: 대상 크레이트 전체
- 면제: `tests/mutants/exempt.toml` (사람만 — `mutant`·`reason`·`approved_by`). 동치 뮤턴트나 Drop 제로화처럼
  **정상 동작에 흔적이 없는** 변이만. 대신 무엇이 확인하는지(예: C4-03 감사)를 사유에 쓴다

cargo-mutants 가 만들지 않는 중요한 변이는 아래 표로 관리하고, 대응 테스트를 명시한다.

| 변이 (수동) | 대응 테스트 | 확인 방법 |
|---|---|---|
| open 이 태그 검증 전에 복호화 | in-place 인증 실패 시 암호문 보존 | 리뷰 + 임시 패치로 실패 확인 |
| 겹침 구간 끝 off-by-one | 1바이트 겹침 코퍼스 | 동일 |
| 상태 확인과 lock 순서 뒤바꿈 | 자가시험 실패 직후 서비스 차단 (동시성) | 동일 |

## 10. 실패 주입

- `fault-injection` feature 로만 켜진다. 검증 빌드(기본 feature, 릴리스)에 주입 코드가 **없음**을 테스트한다
  (예: 릴리스 `.so` 에 주입 심볼이 없음 — `abi-check` 와 함께)
- 확인 항목: KAT 실패 → 오류 상태 + `SELFTEST`, 무결성 실패 → 오류 상태, 오류 상태에서 허용 서비스만 동작,
  할당 실패 → `NOMEM` + `*out == NULL` + CSP 잔존 없음 + 모듈 상태 불변
- 시험용 빌드를 따로 제출할지는 시험기관과 협의한다 (G1)

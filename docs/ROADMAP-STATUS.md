# 로드맵 현재 상태

> 이 파일은 **세션 시작 훅이 읽어서 컨텍스트에 주입한다.** 항상 최신으로 유지한다.
> 근거: `docs/PLAN.md §마일스톤 로드맵`, §리스크와 열린 질문.
> 기계 게이트의 마일스톤은 `scripts/_common.sh` 의 `CURRENT_MILESTONE` 이다. 바꿀 때 이 문서와 함께 바꾼다 (사람).

## 현재 단계

```
▶ M0 — 기반 (워크스페이스·툴체인·CI·하네스)
```

**진입일**: 2026-10-02
**종료 조건**: 하네스가 **스스로 검증**되고(오라클이 정답 벡터를 통과하고, 벡터 러너·상수 시간 하네스가 일부러 틀린 대상을 잡는다),
게이트 0~6·8 이 동작하며, CI 가 초록이다.

> 구현을 겨냥한 실패 테스트는 M0 에 `develop` 으로 들어가지 않는다. 그것은 M1 의 각 PR 에서 **구현 커밋보다 먼저 오는 테스트 커밋**으로
> 들어간다 (`.agents/WORKFLOW.md` ② "하네스와 구현은 같은 PR"). `develop` 에 빨간 테스트를 두면 M1 의 모든 PR 이 마지막 알고리즘이
> 구현될 때까지 게이트 6·7 에서 실패한다. "하네스가 구현보다 먼저 존재한다"는 목적은 M0 의 오라클·러너 자기 검증으로 충족된다.

### M0 체크리스트

- [ ] 에이전트 워크플로우 (`AGENTS.md`, `.agents/`, 어댑터, 훅, `.githooks/`)
- [ ] `./scripts/bootstrap.sh` 실행, `./scripts/selftest-gates.sh` 통과
- [ ] 워크스페이스: `crates/jamulsoe-{core,module,ffi}` 골격 + `jamulsoe-oracle`·`jamulsoe-ct` (경계 밖)
- [ ] **기준선 결정 (사람)**: `build/baseline.toml` 의 rust·nightly·target_cpu·ct_host_model·프로파일 값 → `rust-toolchain.toml`, `.cargo/config.toml`, 워크스페이스 `[profile.release]` 를 그 값으로
- [ ] **승인 체계 (사람)**: `.github/APPROVERS`, `.github/allowed_signers`(하드웨어 키 권장), GitHub 규칙셋 — `protected` job 을 required check 로, 서명 커밋, 코드 오너 리뷰, **머지 커밋만 허용(스쿼시·리베이스 끔)** (`docs/RELEASE.md`), **머지 전 브랜치 최신화 요구**(순 변경 판정이 낡은 머지 결과로 통과하지 않게 — push 판정이 사후에 한 번 더 본다)
- [ ] `./scripts/bootstrap.sh` 로 `core.hooksPath` 설정 (첫 커밋 **뒤에**)
- [ ] `./scripts/lint-boundary.sh` 통과 (C5-01~04, C5-07)
- [ ] `tests/vectors/`: RFC 5794, RFC 4231, NIST CAVP SHA-256 원본 + `SOURCES.md`
- [ ] KISA 검증대상 알고리즘 테스트 벡터 확보 (사람) → 추가
- [ ] 벡터 러너 자기 검증: 오라클로 정답 벡터를 통과하고, 기대값 한 바이트를 바꾼 사본으로는 **기대값 불일치로** 실패한다 (러너가 실제로 비교함)
- [ ] `jamulsoe-oracle`: ARIA·GHASH·SHA-256·HMAC 참조 모델 — 상수는 `docs/standards/` 원문에서 출처 주석과 함께, 정답 벡터 통과. 가능하면 다른 계열 모델로 작성
- [ ] KS X 1213-1 등 재배포 불가 원문 확보 → `docs/standards/local/` + 해시 기록 (사람)
- [ ] `jamulsoe-ct`: `ctgrind`(CI)·`dudect`(기준 장비) 바이너리 + **일부러 새는 대상**을 잡는 자기 시험
- [ ] dudect 기준 장비 마련 (사람) — `ct_host_model` 기록
- [ ] CI(ubuntu-24.04): `JMS_REQUIRE_ALL=1 ./scripts/verify.sh` + 보호 경로 검사
- [ ] `docs/provenance.md` 첫 항목들 (참고한 자료가 생기는 즉시)

## G1 대기 질문

`docs/kcmvp/inquiries.md` 에 질문·답변이 기록될 때까지 **아래에 의존하는 결정은 하지 않는다.**

| 질문 (계획서 §시험기관에 확인할 질문) | 막히는 것 |
|---|---|
| 개인(사업자) 명의 신청·계약 가능 여부 | 검증 경로 자체 |
| 소스 공개 모듈 접수, 형상관리 유의점 | 저장소·브랜치 정책 |
| Rust 구현·std 정적 링크 | 경계 정의, `no_std` cdylib 전환 여부 |
| DRBG 없이 키·IV 외부 주입 GCM 허용 | v1 범위 (CTR_DRBG 를 당길지) |
| 96비트 IV·128비트 태그만으로 구현적합성 시험, GCM 최대 입력 허용값 | `JMS_GCM_MAX_*` 값, API |
| 블록암호 구현적합성 시험에 ECB 등 원시 블록 인터페이스 필요 여부 | core 노출 범위, export 목록 |
| 무결성 태그 위치·경계 포함 | 모듈 경계, `tools/integrity` |
| 알고리즘 KAT 의 자가시험 분류 | 보안정책문서 |
| 모듈 전체 제로화 필요 여부, 오류 전이 시 기존 컨텍스트 즉시 제로화 | 컨텍스트 레지스트리 (구조 변경) |
| 무결성 시험용 고정 HMAC 키의 CSP 해당 여부 | CSP 인벤토리 |
| 시험 수수료·대기·소요 기간 | 일정 |

## 사람이 할 일 — 순서대로 (출처·절차: `docs/research/2026-10-03.md`)

**마감 있음**
- [ ] **심화교육 신청 — 2026-10-16(금) 17시**: https://forms.gle/214eKM8AjrfG1f6J7 (교육 10-26~27, 확정 메일 10-22)
- [ ] **GitHub Actions 에서 `pull_request_target` 허용 — 2026-11-02 전** (Settings → Actions → General). 안 하면 보호 경로 판정이 돌지 않는다

**첫 커밋 전후**
- [ ] 셸로 고친 보호 파일 diff 검토, `docs/PLAN.md` 를 원본과 대조
- [ ] 서명 키 두 개: 일상 키(소프트웨어) + 승인 키(하드웨어 `ed25519-sk`, `brew install openssh` 필요). 둘 다 GitHub Signing Key 로 등록, 승인 키만 `.github/allowed_signers` 에 (§4.3)
- [ ] dev@devgyurak.com 이 devgyurak 계정의 확인된 이메일인지 확인 (Verified 조건)
- [x] 첫 push — `develop` (2026-10-03, 서명 없음. 승인 키가 생기면 보호 경로 커밋을 승인 키로 다시 서명해야 `main` 릴리스 PR 의 판정을 통과한다)
- [ ] `./scripts/bootstrap.sh` (`core.hooksPath` 설정)
- [ ] `./.github/rulesets/apply.sh` 로 확인 → `--apply` (기본 브랜치 develop, 머지 커밋만, `develop`·`kcmvp/**` 규칙셋. `main` 규칙셋은 첫 릴리스로 `main` 을 만든 뒤)

**M0 안에**
- [ ] `build/baseline.toml` 값 결정 — 제안: rust 1.99.0, nightly-2026-09-30, target_cpu x86-64, lto fat, codegen-units 1, strip symbols, opt-level 3 (§3)
- [ ] dudect 기준 장비 마련 (터보·SMT 끄기 등 §3) → `ct_host_model`
- [ ] 표준 원문: KS X 3254·3275 (국립전파연구원 무료), KS X 1213-1 (KSSN 23,100원 또는 e-나라 무료 열람) → `docs/standards/local/` + 해시 (§2)
- [ ] KISA 자료 내려받기: 제출물 작성 안내서 2025.9., GVI Part 1·2, 테스트 벡터 zip(ARIA·SHA2·HMAC) — 벡터는 재배포 조건 확인 전까지 로컬에만 (§1.3·1.4)
- [ ] 사전검증 서비스(https://www.kcmvp.or.kr:8084) 개인 회원 가입
- [ ] KISA 참고용 소스코드 요청 — block_128@kisa.or.kr (라이선스 조건 함께 문의)
- [ ] 로드맵 M2~M5 추정을 원본 그림과 대조

**G1 으로**
- [ ] 시험기관 문의: `docs/kcmvp/inquiries.md` Q01~Q12 + `inquiry-drafts.md` D02~D05 → 답변 기록. 창구: §1.6 표 (KISA 02-405-6702 kcmvp@kisa.or.kr 등)
- [ ] 계획서 정정 반영: KS X 1213-2 는 KISA 참조표준에 없음, KS X 3254·3275 는 방송통신표준 (§2.1)

---

## 마일스톤 미리보기

> ⚠️ **M2~M5 의 내용은 추정이다.** 계획서의 로드맵 그림("7단계, 게이트 2개")은 원본 문서에만 있고
> `docs/PLAN.md` 에는 없다. 본문(§개요, §리스크, §마일스톤 로드맵)에서 다음과 같이 추정했다. **사람이 그림과 대조해 고친다.**

| 단계 | 핵심 | 근거 |
|---|---|---|
| M1 알고리즘 코어 | ARIA·GCM·SHA-256·HMAC in `jamulsoe-core`, 상수 시간, 정답 벡터·차등·CT 게이트 | "M0~M1(알고리즘 코어)" |
| **G1 경계·API 동결** | 시험기관 답변 반영, 경계·공개 API·`exports.txt` 확정 (사람) | "모듈 경계와 공개 API는 G1에서 동결" |
| M2 모듈 | 상태머신, 자가시험, 무결성 시험, 제로화 | 크레이트 구조 (추정) |
| M3 C ABI | `jamulsoe-ffi`, 헤더, 실패 코퍼스, 퍼징, Miri/ASan, 바인딩 예제 | 크레이트 구조 (추정) |
| M4 검증 강화·공개 | 재현 빌드, CI 두 러너, v0.1 공개 | "v0.1 공개까지 약 4~5개월" (추정) |
| M5 제출물 | 설계서·보안정책문서·형상관리, 구현적합성 사전 시험 | KCMVP 요건 매핑 (추정) |
| **G2 시험 신청** | 신청 결정 (사람) | "시험 신청까지 약 6~9개월" (추정) |
| M6 시험 대응 | `kcmvp/v1` 동결, 보완 대응 | "M6 기간은 시험기관 대기열과 보완 횟수에 따라" |

---

## 후속 과제 (선택 — 막는 문제는 아님)

- **R1 증거의 기계 확인**: 지금 R1 의 증거는 PR 본문에 붙인 실패 출력이라 리뷰어 확인에 의존한다.
  CI 가 PR 의 `TEST:` 커밋을 체크아웃해, 그 PR 이 레지스트리에 새로 연결한 테스트를 돌려 **기대값 불일치로 실패했는지** 확인하는 job 을 둘 수 있다.
  PR 코드를 실행하므로 `ci.yml`(pull_request) 쪽에 둔다 — `protected.yml`(base 의 판정기)에 넣지 않는다.
  빌드 오류·`todo!()` 패닉과 기대값 불일치를 구분하는 방법을 함께 정해야 한다. 제안: 2026-10-03 외부 리뷰.

## 이 단계에서 하지 말 것

> **G1 전에는 M0~M1 만 한다.**

- `jamulsoe-module`·`jamulsoe-ffi` 의 공개 동작·API 를 확정하지 않는다 (골격과 하네스 설계까지만)
- `exports.txt`·`include/jamulsoe.h` 를 만들지 않는다
- 무결성 태그 저장 방식을 고안하지 않는다
- 비목표(DRBG, 공개키, TLS, 하드웨어 가속, Windows/macOS)를 시작하지 않는다

---

## 갱신 로그

| 날짜 | 변경 |
|---|---|
| 2026-10-02 | M0 시작. 계획서 동결본(`docs/PLAN.md`) 기준으로 에이전트 워크플로우 구축 |

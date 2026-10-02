# 브랜치 · 릴리스 · 형상

근거: `docs/PLAN.md §빌드·배포·형상관리`.

## 브랜치

```
feat/… fix/… test/… docs/…  ──PR──►  develop (통합, 기본 브랜치)  ──릴리스 PR──►  main (릴리스)  ──►  서명 태그 vX.Y.Z
                                         ▲                                         │
                                         └──────── main 을 다시 머지 ◄── hotfix/* ──┘
                                                                         검증 제출 태그 ──► kcmvp/v1 (동결)
```

| 브랜치 | 정책 | 강제 |
|---|---|---|
| 작업 브랜치 (`feat/…`, `fix/…`, `test/…`, `docs/…`) | 에이전트·사람이 작업. **`develop` 으로 PR** | — |
| `develop` | **통합 브랜치**, 저장소 기본 브랜치. PR 필수, 머지 커밋만, 서명 필수, 필수 체크 2개, 머지 전 최신화, force push·삭제 금지 | 규칙셋 `develop.json` |
| `main` | **릴리스 브랜치.** `develop` 에서 오는 릴리스 PR 과 `hotfix/*` PR 만 받는다. 머지 뒤 서명 태그를 단다. 규칙은 `develop` 과 같다 | 규칙셋 `main.json` + PR 출처 검사(`protected.yml`) |
| `hotfix/*` | `main` 에서 갈라 긴급 수정. `main` 으로 PR, 릴리스 뒤 `main` 을 `develop` 에 머지해 되돌려 넣는다 | — |
| `kcmvp/v1` | 검증 제출 버전 **동결** (제출 태그에서 가른다). 변경은 곧 재검증 사유 | 규칙셋 `kcmvp.json` + `.githooks/pre-push` |

에이전트는 `develop`·`main`·`kcmvp/*` 에 직접 push 하지 않는다. 작업 브랜치에서 PR 을 연다.

### 릴리스 절차

1. `develop` 이 릴리스할 상태다: CI 초록, 마일스톤 종료 판정(`verify.sh --milestone Mx`, 기준 장비) 통과, 감사 기록 유효
2. `develop` → `main` **릴리스 PR** (머지 커밋). 본문에 버전, 변경 요약, 계약·ABI 영향
3. 머지 뒤 `main` 의 머지 커밋에 **서명 태그** `vX.Y.Z` (사람). 릴리스 산출물을 첨부한다
4. 검증 제출본이면 그 태그에서 `kcmvp/v1` 을 가른다

## 머지 방식 — 머지 커밋만

PR 은 **머지 커밋**으로만 들어간다. GitHub 규칙셋에서 스쿼시 머지와 리베이스 머지를 끈다 (사람이 설정).

| 방식 | 문제 |
|---|---|
| 스쿼시 | 새 커밋을 GitHub 이 만들고 서명한다 — **승인자 서명이 사라져** 보호 경로 변경이 CI 판정에 실패한다. 감사 기록의 `commit` 이 HEAD 의 조상이 아니게 되어 manual 증거가 전부 무효가 된다 |
| 리베이스 | 커밋을 다시 만든다 — 같은 두 문제 |
| **머지 커밋** | 승인된 커밋과 감사한 커밋이 그대로 남는다. 머지 커밋 자체는 모든 부모와 다른 파일만 판정한다 (`scripts/check-protected-diff.sh`) |

PR 브랜치를 최신으로 맞출 때도 리베이스가 아니라 대상 브랜치(`develop`)를 머지해 넣는다 (승인 서명이 있는 커밋을 다시 만들지 않기 위해).

규칙셋에서 **머지 전 브랜치 최신화**를 요구한다. 보호 경로 판정은 PR 의 머지 결과(`refs/pull/N/merge`)로 순 변경을 보므로,
base 가 그 뒤에 움직이면 판정이 낡는다. `develop`·`main` 에 push 된 뒤의 판정(`protected.yml` push 이벤트)이 같은 검사를 한 번 더 한다.

머지에서 한쪽 부모의 **옛 버전을 고르는 것**도 보호 경로 변경이다. 커밋별 검사에는 걸리지 않지만 순 변경 검사가 잡는다 —
그 내용을 만든 승인·서명 커밋이 범위에 없으면 실패한다 (`scripts/check-protected-diff.sh`).

## 서명 키

"서명 필수" 규칙은 PR 의 **모든** 커밋에 적용된다 (에이전트 커밋 포함). 그래서 키를 둘로 나눈다 (`docs/research/2026-10-03.md` §4.3).

| 키 | 용도 | 등록 |
|---|---|---|
| 일상 서명 키 (소프트웨어) | 모든 커밋 | GitHub Signing Key |
| 승인 키 (하드웨어 `ed25519-sk`, 서명마다 터치) | `Approved-by:` 가 붙는 보호 경로 변경 커밋 | GitHub Signing Key + `.github/allowed_signers` |

일상 키는 `allowed_signers` 에 없으므로 그 서명은 승인으로 인정되지 않는다. 코드 오너 리뷰는 요구하지 않는다 — 혼자 운영하면 자기 PR 을 승인할 수 없고, 승인의 증거는 서명이다.

## GitHub 설정 적용

`.github/rulesets/apply.sh` (사람이 실행). `develop` 규칙셋은 지금, `main` 규칙셋은 첫 릴리스로 `main` 을 만든 뒤에 건다. Actions 의 `pull_request_target` 허용은 UI 에서 (2026-11-02 부터 기본 차단).

## 버전·태그

- 릴리스는 `main` 에서만 나간다. SemVer (`v0.1.0`, …)
- 검증 제출본: `v1.0.0-kcmvp` 형식의 **서명된 태그**
- 태그 생성은 사람만 한다

## 릴리스 산출물

`libjamulsoe.so`, 무결성 태그, SHA-256 목록, SBOM, 툴체인 기준선 명세(`rust-toolchain.toml`,
`Cargo.lock` 해시, 컨테이너 다이제스트, 링커·binutils·glibc 버전, target triple, CPU 기준선, 프로파일 설정).

검증 릴리스는 `cdylib` 만 만든다. staticlib 은 검증 대상이 아니다.

## 재현 가능한 빌드

- 다이제스트로 고정한 컨테이너 이미지
- `SOURCE_DATE_EPOCH`, `--remap-path-prefix`
- `-C target-cpu=native` 금지, CPU 기준선 명시
- CI 가 서로 다른 두 러너에서 빌드해 SHA-256 비교 (`./scripts/repro.sh` 의 CI 판)

재현 빌드는 공식 바이너리가 공개 소스에서 나왔음을 **제3자가 확인**하게 하는 장치다.
사용자가 직접 빌드한 결과물에 검증효력을 주지 않는다. 검증효력은 모듈명·버전·운영환경·형상 기준이다.

## 보안 수정

급하면 `hotfix/*` → `main`(릴리스) → `develop` 으로 되돌려 넣고, 아니면 일반 흐름(`develop` → 다음 릴리스)으로 간다. 심각도에 따라 재검증 신청 여부를 **사람이** 판단한다.
`kcmvp/v1` 에 반영해야 하는 경우도 사람이 결정한다.

## 기여

- Apache-2.0
- DCO: 모든 커밋에 `Signed-off-by:` (`.githooks/commit-msg` 가 강제)
- 저장소 관리자 계정은 2단계 인증 (시험기관의 개발 환경 보안 점검 대비)

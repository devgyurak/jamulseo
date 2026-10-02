---
description: 빌드·형상 규칙 — 재현 빌드, 툴체인 기준선, 무결성 태그
paths:
  - "tools/**"
  - "build/**"
  - ".github/**"
  - "rust-toolchain.toml"
  - "Cargo.toml"
  - "crates/*/Cargo.toml"
globs:
  - "tools/**"
  - "build/**"
  - ".github/**"
  - "rust-toolchain.toml"
  - "Cargo.toml"
  - "crates/*/Cargo.toml"
alwaysApply: false
order: 260
---

# 규칙: 빌드 · 형상

적용: `tools/**`, `build/**`, `.github/**`, `rust-toolchain.toml`, `Cargo.toml` · 전문: 계획서 §빌드·배포·형상관리, `docs/RELEASE.md`

## 절대 규칙

1. **`-C target-cpu=native` 금지.** CPU 기준선은 명시적으로 고정하고 보안정책문서와 같아야 한다
2. **툴체인 기준선은 형상이다.** `rust-toolchain.toml` 변경은 사람 승인 + 상수 시간 검사·어셈블리 감사 재수행
3. 릴리스 프로파일: `panic = "abort"`, `lto`·`codegen-units`·`strip` 고정 (`lint-boundary` 가 `panic` 을 검사)
4. **경계 크레이트에 외부 의존 0** — `build-dependencies` 포함
5. 산출물은 `cdylib` 만. staticlib 금지
6. 빌드 컨테이너는 **다이제스트로 고정**. 태그 금지
7. `SOURCE_DATE_EPOCH` · `--remap-path-prefix` 로 경로·시각 제거. 재현 실패 시 비교를 느슨하게 하지 말고 원인을 찾는다
8. `.github/workflows/*` 는 판정 경로다 — 수정은 사람 승인 (`.agents/APPROVAL.md`)

## 무결성 태그 (`tools/integrity/`)

- 경계 밖 도구다. 모듈과 **같은 HMAC-SHA-256 구현**을 써야 태그가 일치한다
- 태그 위치(별도 `.hmac` 파일 vs 바이너리 내장)와 키 관리는 **G1 질문** — 독자 고안 금지
- 한계: 바이너리와 태그를 함께 바꿀 수 있는 공격자에 대한 신뢰 기준점이 아니다. 문서에서 과장하지 않는다

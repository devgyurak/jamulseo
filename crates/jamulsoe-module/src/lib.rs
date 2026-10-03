//! jamulsoe 모듈 계층 — 모듈 경계 안 (docs/PLAN.md §C ABI 설계 > 규칙).
//!
//! 상태머신·자가시험·무결성 시험·CSP 제로화. `unsafe` 금지, 의존은 `jamulsoe-core` 하나 (C5-02, C5-03).
//! 공개 동작은 G1(경계·API 동결) 이후 M2 에서 정한다 (docs/ROADMAP-STATUS.md).
#![forbid(unsafe_code)]
#![warn(missing_docs)]

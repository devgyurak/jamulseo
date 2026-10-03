//! jamulsoe 알고리즘 코어 — 모듈 경계 안 (docs/PLAN.md §알고리즘 구현 계획).
//!
//! `no_std`, 힙 없음, `unsafe` 금지, 외부 의존 0 (docs/CONTRACTS.md C5-01, C5-03).
//! 비밀값으로 분기·인덱싱하지 않는다 (C1). 구현은 M1 에서 하네스(정답 벡터·오라클)가 먼저 온 뒤 들어온다 (AGENTS.md R1).
#![no_std]
#![forbid(unsafe_code)]
#![warn(missing_docs)]

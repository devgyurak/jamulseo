//! jamulsoe C ABI — 모듈 경계 안, 검증 대상 바이너리 `libjamulsoe.so` (docs/PLAN.md §C ABI 설계).
//!
//! `unsafe` 가 허용되는 유일한 크레이트다 — 블록마다 `// SAFETY:` 근거 (AGENTS.md R6).
//! 의존은 `jamulsoe-module` 하나 — core 를 직접 부르면 상태 검사(C3)를 우회한다 (C5-02).
//! 공개 API·`exports.txt`·헤더는 G1 이후 M3 에서 정한다. 그 전에는 아무것도 export 하지 않는다.
#![deny(unsafe_op_in_unsafe_fn)]
#![warn(missing_docs)]

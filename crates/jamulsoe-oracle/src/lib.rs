//! jamulsoe 독립 참조 모델 — **모듈 경계 밖**, 차등 테스트의 오라클 (.agents/INDEPENDENCE.md).
//!
//! 경계 크레이트를 의존하지 않고 그 구현을 읽지 않는다. 상수는 docs/standards/ 원문에서 출처 주석과 함께 옮긴다.
//! 느리고 단순해도 된다 — 표준과 대조하기 쉬운 것이 목표다. 구현은 M0 하네스 작업에서 oracle-author 가 쓴다.
#![forbid(unsafe_code)]
#![warn(missing_docs)]

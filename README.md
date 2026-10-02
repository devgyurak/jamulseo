# jamulsoe

Rust로 구현하고 C ABI(`libjamulsoe.so` + `jamulsoe.h`)로 제공하는 오픈소스 국산 암호 모듈.
1차 목표는 ARIA-GCM · SHA-256 · HMAC-SHA-256 범위로 **KCMVP 보안등급 1 검증**을 받는 것이다.

> **상태: M0 (기반 구축).** 아직 구현이 없다. KCMVP 검증을 **준비 중**이며 검증서가 발급되지 않았다.

- 구현 계획 (동결본): [`docs/PLAN.md`](docs/PLAN.md)
- 계약: [`docs/CONTRACTS.md`](docs/CONTRACTS.md)
- 현재 단계: [`docs/ROADMAP-STATUS.md`](docs/ROADMAP-STATUS.md)

## 기여

- 라이선스: Apache-2.0
- 모든 커밋에 DCO `Signed-off-by:` (`git commit -s`) — [`docs/COMMIT.md`](docs/COMMIT.md)
- 처음 열면: `./scripts/bootstrap.sh`

### 에이전트로 작업할 때

이 저장소는 코딩 에이전트(Claude Code, Codex, opencode, Cursor, pi)와 함께 개발한다.
규약의 단일 원천은 [`AGENTS.md`](AGENTS.md), 작업 루프는 [`.agents/WORKFLOW.md`](.agents/WORKFLOW.md) 다.

```
① SPEC → ② HARNESS → ③ IMPL → ④ VERIFY → ⑤ REVIEW → ⑥ RECORD
```

진짜 게이트는 도구가 아니라 `./scripts/verify.sh` 와 CI 다.

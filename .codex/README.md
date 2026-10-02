# Codex 사용법

Codex 는 루트 `AGENTS.md` 를 자동으로 읽는다.

## 서브에이전트

`.codex/agents/*.toml` 에 13개 역할이 있다. **`scripts/sync-agents.sh` 가 `.agents/roles/*.md` 에서 생성한다. 직접 수정하지 않는다.**

```bash
./scripts/sync-agents.sh          # 생성·갱신
./scripts/sync-agents.sh --check  # 드리프트 검사
```

## 역할 독립성

`sandbox_mode = "read-only"` 가 리뷰어·레드팀의 **쓰기**를 막는다. **읽기 경로는 강제하지 못한다.**
`oracle-author` · `spec-redteam` 은 `.agents/INDEPENDENCE.md` 의 절차로 독립성을 지킨다:

```bash
./scripts/spec-bundle.sh --for oracle-author   # 명세 전용 묶음 (target/spec-bundle/)
```

세션을 이어 쓰지 않는다 (`resume` 금지). 구현 요약을 "참고용으로" 넘기는 것도 오염이다.

## 게이트

Codex 는 훅이 제한적이므로 `.githooks/` 가 같은 검사를 한다.

```bash
./scripts/bootstrap.sh                # core.hooksPath 설정 포함
./scripts/verify.sh --fast            # 작업 중
```

## 프로필

`config.toml` 의 프로필은 서브에이전트와 별개로 **직접 실행용**이다: `codex --profile impl-core`.

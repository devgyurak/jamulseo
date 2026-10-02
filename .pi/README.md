# pi 사용법

> ⚠️ **확인 필요**: `.pi/config.toml` 은 **제네릭 템플릿**이다.
> pi 의 실제 설정 경로·스키마를 확인하고 키 이름을 맞춘 뒤 해당 주석을 지우세요.

## 이것이 틀려도 괜찮은 이유

jamulsoe 워크플로우는 **도구의 훅에 의존하지 않도록** 설계되어 있다.

- 규약은 루트 `AGENTS.md` 에 있다 — pi 가 이것만 읽어도 성립한다
- 게이트는 `.githooks/` 와 `./scripts/verify.sh`, 최종 판정은 CI 가 한다
- 역할 분리는 `.agents/roles/<이름>.md` 를 새 세션 첫 메시지로 넣어서 지킨다

## 최소 설정

```bash
./scripts/bootstrap.sh       # git hooks 포함
```

그다음 pi 세션에서:

```
AGENTS.md 를 읽고 시작하세요. 현재 마일스톤은 docs/ROADMAP-STATUS.md 에 있습니다.
```

## 역할 분리 (R3)

| 역할 | 주의 |
|---|---|
| `spec-redteam` | 🚫 구현 코드를 읽지 않는다 — 새 세션, `./scripts/spec-bundle.sh --for spec-redteam` 만 |
| `oracle-author` | 🚫 경계 크레이트 구현을 읽지 않는다 — 새 세션 |
| `rust-reviewer` / `contract-auditor` / `ct-auditor` | 🚫 구현 세션과 분리 |

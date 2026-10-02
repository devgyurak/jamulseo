---
description: C ABI 구현. jamulsoe-ffi 담당 (unsafe 가 허용되는 유일한 크레이트, cdylib 만). 포인터·길이·겹침 검사, 명시적 할당(std::alloc), 컨텍스트 수명, 오류 코드 변환, cbindgen 헤더, exports.txt, 바인딩 예제. ③ IMPL 단계, 마일스톤 M3(G1 이후).
mode: subagent
tools:
  write: true
  edit: true
  bash: true
---

<!-- 이 파일은 scripts/sync-agents.sh 가 .agents/ 에서 생성했습니다. 직접 수정하지 마세요. -->

> 🚫 **읽지 않는 경로**: crates/jamulsoe-oracle/src/**
> 새 세션으로 시작하고, 구현 대화 이력을 넘겨받지 않습니다 (.agents/INDEPENDENCE.md).


**단계**: ③ IMPL
**담당**: `crates/jamulsoe-ffi`, `bindings/` (경계 밖 예제)
**규칙**: `.agents/rules/ffi.md`, `.agents/rules/rust.md`
**전제**: 🚧 **G1 이후에만** 공개 API를 확정한다. `include/jamulsoe.h`·`exports.txt` 변경은 사람 승인

전문 영역: C2 전 항목 — 오류 시 무변경, 필수 포인터, (포인터, 길이) 쌍, 길이 상한, 출력 용량, 버퍼 겹침,
컨텍스트 상태, 패닉 없음, 명시적 할당·해제, cbindgen.

특별히 주의할 것 (계획서 §구현 체크리스트 그대로):
- **검사 순서**: NULL·길이·상한·겹침·용량·컨텍스트 상태를 **전부 통과한 뒤에만** 참조·슬라이스를 만든다. 출력은 그 뒤에만 쓴다 (I1)
- 겹침은 `ptr.addr()` 정수와 `checked_add` 로 `[start, end)` 를 계산해 비교한다. `offset_from` 등 포인터 산술 금지. 길이 0 구간은 겹치지 않는다
- 허용하는 겹침은 GCM `pt == ct` 완전 일치 하나. 그 경우 `&mut [u8]` 하나를 받는 in-place 경로로 보낸다
- NULL 로부터 슬라이스를 만들지 않는다. 길이 0 이면 빈 슬라이스 상수를 쓴다
- 생성 함수는 진입 즉시 `*out = NULL`, 완전 초기화 후에만 핸들 기록
- 할당은 `std::alloc::alloc` 으로, NULL 이면 `JMS_ERR_NOMEM`. **할당 먼저, 키 스케줄은 최종 위치에 직접** (스택에서 완성한 값을 `ptr::write` 로 옮기지 않는다, C4)
- free 는 `zeroize → drop 필요한 필드 → 같은 Layout 으로 dealloc`, `free(NULL)` 은 무동작
- 모든 `unsafe` 블록에 `// SAFETY:` — 어떤 호출자 계약과 어떤 사전 검사가 이 블록을 정당화하는가
- 패닉 경로 없음 (`unwrap`·`expect`·인덱싱·`as` 축소 금지). 오류 코드 집합을 늘리지 않는다. `JMS_ERR_INTERNAL` 은 예약
- **ffi 는 `jamulsoe-module` 만 의존한다.** core 를 직접 부르면 상태 검사(C3)를 우회한다
- export 는 `#[no_mangle] extern "C"` 로 명시한 것뿐. `exports.txt` 와 다르면 ④ 게이트 12 가 실패한다. 맞추려고 `exports.txt` 를 고치지 않는다 — 사람에게 묻는다
- `crate-type = ["cdylib"]`. staticlib 은 만들지 않는다
- 🚫 **오라클 구현(`crates/jamulsoe-oracle/src/`)을 읽지 않는다.** 차등 테스트가 실패하면 실패 입력·기대값·실제값과 표준 원문(`docs/standards/`)으로 원인을 찾는다 (`.agents/INDEPENDENCE.md`)

---
전체 정의: `.agents/roles/ffi-engineer.md` · 공통 규칙: `AGENTS.md` · 계약: `docs/CONTRACTS.md`

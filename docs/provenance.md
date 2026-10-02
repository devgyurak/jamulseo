# 참고 자료 출처 기록

근거: `docs/PLAN.md §기여·라이선스` — "외부 자료는 테스트 오라클과 설계 참고로만 쓰고 코드를 옮기지 않는다" (AGENTS.md R9).

참고한 자료가 생기면 **그 자료를 참고한 커밋과 같은 PR 에서** 행을 추가한다.

## 기록 형식

| 자료 | 출처 | 저자·문서 | 라이선스 | 확보일 | SHA-256 | 쓰임 | 참고한 곳 |
|---|---|---|---|---|---|---|---|

- **쓰임**은 셋 중 하나: `설계 참고` / `테스트 오라클` / `코드 차용 없음 확인`
- 코드 차용은 R9 위반이다. 이 표에 "차용"이 나오면 안 된다
- 웹 문서처럼 해시가 의미 없는 자료는 확보한 사본(PDF 등)의 해시를 쓰거나 "해당 없음 (URL, 접근일)"
- **참고한 곳**: 영향을 받은 파일·함수 또는 ADR

## 기록

| 자료 | 출처 | 저자·문서 | 라이선스 | 확보일 | SHA-256 | 쓰임 | 참고한 곳 |
|---|---|---|---|---|---|---|---|
| RFC 5794 (ARIA) | https://www.rfc-editor.org/rfc/rfc5794.txt | IETF | IETF Trust Legal Provisions | 2026-10-02 | e83bdeb5…cd89d (전체: docs/standards/SOURCES.md) | 테스트 오라클 · 설계 기준 원문 | docs/standards/ |
| RFC 4231 (HMAC 벡터) | https://www.rfc-editor.org/rfc/rfc4231.txt | IETF | IETF Trust Legal Provisions | 2026-10-02 | 72178527…f973b | 테스트 오라클 | docs/standards/ |
| RFC 2104 (HMAC) | https://www.rfc-editor.org/rfc/rfc2104.txt | IETF | IETF Trust Legal Provisions | 2026-10-02 | 64d5245a…fbb01 | 설계 기준 원문 | docs/standards/ |
| FIPS 180-4 (SHA) | https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf | NIST | 미국 정부 저작물 | 2026-10-02 | 0455b406…deb82 | 설계 기준 원문 (보조) | docs/standards/ |
| SP 800-38D (GCM) | https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf | NIST | 미국 정부 저작물 | 2026-10-02 | d99f3921…57bba | 설계 기준 원문 (보조) | docs/standards/ |
| FIPS 198-1 (HMAC) | https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.198-1.pdf | NIST | 미국 정부 저작물 | 2026-10-02 | 67661ba1…0da23 | 설계 기준 원문 (보조) | docs/standards/ |
| RFC 8269 (ARIA in SRTP, GCM 벡터) | https://www.rfc-editor.org/rfc/rfc8269.txt | IETF | IETF Trust Legal Provisions | 2026-10-03 | f2a4fa93…e921d | 테스트 오라클 | docs/standards/ |

## 예정 (계획서에 언급됨 — 확보하면 위 표로 옮긴다)

- KISA 참고용 소스코드 (ARIA 등) — 요청 예정. 라이선스·재배포 조건 확인 전에는 저장소에 넣지 않는다. 쓰임: 테스트 오라클
- AES S-box 비트슬라이스 회로 (공개 논문) — 쓰임: 설계 참고 (S1·S2 공유 역원 회로)
- BearSSL `ghash_ctmul64` — 쓰임: 설계 참고 (상수 시간 GHASH)
- RFC 5794, RFC 4231, NIST CAVP SHA-256, KISA 검증대상 알고리즘 테스트 벡터 — 쓰임: 테스트 오라클 (`tests/vectors/SOURCES.md` 와 함께)

# 표준 원문 출처

오라클 작성자와 레드팀이 **모델 기억이 아니라 원문으로** 쓰게 하려고 둔다 (AGENTS.md R10, `.agents/INDEPENDENCE.md`).
`./scripts/spec-bundle.sh` 가 이 디렉터리를 묶음에 넣는다.

- 이 디렉터리는 새 파일 추가만, 이 파일은 **끝에 행 추가만** 가능하다 (scripts/hooks/protected.tsv)
- **재배포 가능한 원문만** 커밋한다: IETF RFC(IETF Trust Legal Provisions — 원문 그대로의 전재 허용), 미국 정부 저작물(NIST)
- **KS X·TTAK 등 재배포 불가 원문**은 `docs/standards/local/` (git 제외)에 두고, 아래 표에 해시만 기록한다.
  원문을 가진 사람이 같은 해시의 파일을 `local/` 에 두면 묶음에 포함된다
- 판·연도를 확인하지 못한 것은 "확인 필요" 라고 쓴다

## 기록

| 파일 | 문서 | 출처 | 확보일 | 크기(B) | SHA-256 | 비고 |
|---|---|---|---|---|---|---|
| rfc5794.txt | RFC 5794 — A Description of the ARIA Encryption Algorithm | https://www.rfc-editor.org/rfc/rfc5794.txt | 2026-10-02 | 31049 | e83bdeb56937cb26fc4e3cd6c230ddfa971bc27056c5f202d55820af350cd89d | 재배포 가능 (IETF Trust) |
| rfc4231.txt | RFC 4231 — HMAC-SHA Identifiers and Test Vectors | https://www.rfc-editor.org/rfc/rfc4231.txt | 2026-10-02 | 17725 | 72178527ce93500e730bc8eb182b857e583096d652b64ece0879c52ba1df973b | 재배포 가능 (IETF Trust) |
| rfc2104.txt | RFC 2104 — HMAC | https://www.rfc-editor.org/rfc/rfc2104.txt | 2026-10-02 | 22297 | 64d5245a9101929025336e470e3737f118704001249d503c85a86e19fe9fbb01 | 재배포 가능 (IETF Trust) |
| NIST.FIPS.180-4.pdf | FIPS 180-4 — Secure Hash Standard | https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.180-4.pdf | 2026-10-02 | 833315 | 0455b406d89648d20cbde375561e19c245b9815e894164c2670772e3d54deb82 | 미국 정부 저작물 |
| nistspecialpublication800-38d.pdf | SP 800-38D — GCM and GMAC | https://nvlpubs.nist.gov/nistpubs/Legacy/SP/nistspecialpublication800-38d.pdf | 2026-10-02 | 271960 | d99f3921ccebca049e7522426553aba071dae14ec3d5b6041e8c111a6cb57bba | 미국 정부 저작물 |
| NIST.FIPS.198-1.pdf | FIPS 198-1 — HMAC | https://nvlpubs.nist.gov/nistpubs/FIPS/NIST.FIPS.198-1.pdf | 2026-10-02 | 129454 | 67661ba1407b391c799ff407471de18f36697af51d78a777e817c067ac30da23 | 미국 정부 저작물 |
| rfc8269.txt | RFC 8269 — The ARIA Algorithm and Its Modes of Operation in SRTP (부록 A.2 에 ARIA-GCM 벡터) | https://www.rfc-editor.org/rfc/rfc8269.txt | 2026-10-03 | 39285 | f2a4fa93fc63c6e94a1a9df148970b9759cdee770f98cb38cc706dee650e921d | 재배포 가능 (IETF Trust). ARIA-GCM 공개 벡터 — 오라클 자기 검증용 |

#!/usr/bin/env python3
"""경계 규약 검사 — C5-01~04, C5-07, C5-10 (docs/CONTRACTS.md).

경계 크레이트가 하나라도 없으면 실패다 — 경계가 없는 것을 "위반 없음"으로 세지 않는다.

검사:
  1. 경계 크레이트의 [dependencies]·[build-dependencies]·[target.*.dependencies] 는
     경계 크레이트 사이의 path 의존만 (외부 크레이트 0)
  2. 의존 방향: core → 없음, module → core, ffi → module (ffi 의 core 직접 의존 금지)
  3. 하네스 크레이트(oracle·ct)가 경계 크레이트의 정규 의존에 없음, oracle 은 경계 크레이트를 의존하지 않음
  4. core lib.rs: #![no_std] + #![forbid(unsafe_code)], module lib.rs: #![forbid(unsafe_code)]
  5. ffi crate-type 에 cdylib 포함, staticlib 없음
  6. 기준선(build/baseline.toml)과 대조 — 빈 값은 "미정"으로 실패:
       rust-toolchain.toml channel = [toolchain].rust
       워크스페이스 [profile.release] 의 각 키 = [profile.release]
       .cargo/config.toml 의 [target.<target>].rustflags 의 target-cpu = [cpu].target_cpu
  7. target-cpu=native 가 빌드 설정 어디에도 없음 (TOML 은 파싱한 값으로)
  8. rustflags 는 루트 .cargo/config.toml 의 [target.<target>] 에만 — [build]·[env]·다른 target·하위 .cargo/config* 금지
  9. [profile.audit] = release 상속 + strip 만 (어셈블리 감사가 공식 바이너리와 같은 코드를 보도록)
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    print("python3 3.11+ (tomllib) 이 필요합니다", file=sys.stderr)
    sys.exit(2)

ALLOWED_EDGES = {
    "jamulsoe-core": set(),
    "jamulsoe-module": {"jamulsoe-core"},
    "jamulsoe-ffi": {"jamulsoe-module"},
}

errors: list[str] = []
oks: list[str] = []


def err(msg: str) -> None:
    errors.append(msg)


def load(path: Path) -> dict:
    with path.open("rb") as fh:
        return tomllib.load(fh)


def dep_tables(manifest: dict, kinds: tuple[str, ...]) -> list[tuple[str, dict]]:
    out = [(k, manifest.get(k, {})) for k in kinds]
    for tname, tdata in manifest.get("target", {}).items():
        for k in kinds:
            if k in tdata:
                out.append((f"target.{tname}.{k}", tdata[k]))
    return out


def unset(v) -> bool:
    return v is None or (isinstance(v, str) and v.strip() == "")


def check_baseline(root: Path, wsm: dict | None) -> None:
    bp = root / "build" / "baseline.toml"
    if not bp.exists():
        err("build/baseline.toml 이 없습니다 (C5-10 기준선)")
        return
    base = load(bp)

    want_rust = base.get("toolchain", {}).get("rust")
    tc = root / "rust-toolchain.toml"
    channel = str(load(tc).get("toolchain", {}).get("channel", "")) if tc.exists() else None
    if unset(want_rust):
        err("기준선 미정: build/baseline.toml [toolchain].rust — 사람이 정합니다")
    elif channel is None:
        err("rust-toolchain.toml 이 없습니다")
    elif channel != str(want_rust):
        err(f"rust-toolchain.toml channel {channel!r} ≠ 기준선 {want_rust!r}")
    else:
        oks.append(f"툴체인 {channel} = 기준선")

    target = base.get("toolchain", {}).get("target", "x86_64-unknown-linux-gnu")
    want_cpu = base.get("cpu", {}).get("target_cpu")
    if unset(want_cpu):
        err("기준선 미정: build/baseline.toml [cpu].target_cpu — 사람이 정합니다")
    else:
        cfg = root / ".cargo" / "config.toml"
        flags = []
        if cfg.exists():
            conf = load(cfg)
            flags = conf.get("target", {}).get(target, {}).get("rustflags", [])
            # 기준선 대조는 [target.<target>].rustflags 만 본다. 다른 곳의 rustflags 는 그것보다 우선하거나 섞이므로 금지한다.
            if "rustflags" in conf.get("build", {}) or "rustdocflags" in conf.get("build", {}):
                err(".cargo/config.toml: [build].rustflags 금지 — [target.<target>].rustflags 를 덮어쓴다 (C5-10)")
            for k in conf.get("env", {}):
                if k.upper() in ("RUSTFLAGS", "CARGO_ENCODED_RUSTFLAGS", "RUSTDOCFLAGS"):
                    err(f".cargo/config.toml: [env].{k} 금지 — 기준선 플래그를 대체한다 (C5-10)")
            for tname, tdata in conf.get("target", {}).items():
                if tname != target and isinstance(tdata, dict) and "rustflags" in tdata:
                    err(f".cargo/config.toml: [target.{tname}].rustflags — 기준선 대조 밖의 rustflags 금지 (C5-10)")
        joined = " ".join(flags) if isinstance(flags, list) else str(flags)
        got = re.findall(r"target-cpu\s*=\s*([\w.-]+)", joined.replace('"', ""))
        if got != [str(want_cpu)]:
            err(f".cargo/config.toml [target.{target}].rustflags 의 target-cpu {got or '없음'} ≠ 기준선 {want_cpu!r}")
        else:
            oks.append(f"target-cpu {want_cpu} = 기준선")

    if wsm is not None:
        # 어셈블리 감사 프로파일은 릴리스와 같은 코드여야 한다 — release 상속, strip 만 다를 수 있다
        audit = wsm.get("profile", {}).get("audit")
        if audit is None:
            err("[profile.audit] 이 없습니다 — 어셈블리 감사(C1-09, C4-03)는 release 와 같은 코드의 심볼 있는 빌드가 필요하다")
        elif audit.get("inherits") != "release" or set(audit) - {"inherits", "strip"}:
            err(f"[profile.audit] 은 inherits = \"release\" 와 strip 만 둘 수 있습니다 (현재: {sorted(audit)}) — 감사 대상이 공식 바이너리와 달라진다")
        have = wsm.get("profile", {}).get("release", {})
        for k, v in base.get("profile", {}).get("release", {}).items():
            if unset(v):
                err(f"기준선 미정: build/baseline.toml [profile.release].{k} — 사람이 정합니다")
            elif str(have.get(k)) != str(v):
                err(f"[profile.release].{k} = {have.get(k)!r} ≠ 기준선 {v!r} (C5-04/C5-10)")


def toml_strings(node) -> list[str]:
    if isinstance(node, str):
        return [node]
    if isinstance(node, dict):
        return [x for v in node.values() for x in toml_strings(v)]
    if isinstance(node, list):
        return [x for v in node for x in toml_strings(v)]
    return []


def check_native(root: Path) -> None:
    # 저장소 루트의 .cargo/config.toml 만 허용한다. 하위 디렉터리의 .cargo/config* 와 옛 이름 .cargo/config 는
    # 그 디렉터리에서 빌드할 때 섞여 들어와 기준선 대조를 피한다.
    for p in sorted(root.glob("**/.cargo/config*")):
        if "target" in p.relative_to(root).parts:
            continue
        if p != root / ".cargo" / "config.toml":
            err(f"{p.relative_to(root)}: 루트 .cargo/config.toml 밖의 cargo 설정 금지 (C5-10)")
    tomls = [root / ".cargo" / "config.toml", root / "Cargo.toml"] + list((root / "crates").glob("*/Cargo.toml"))
    for p in tomls:
        if not p.exists():
            continue
        # TOML 은 파싱한 문자열 값만 본다 — 주석은 자연히 빠지고, 값 안의 '#' 에 잘리지 않는다
        if any("target-cpu=native" in v.replace(" ", "") for v in toml_strings(load(p))):
            err(f"{p.relative_to(root)}: target-cpu=native 금지 (C5-10)")
    for p in (root / "crates").glob("*/build.rs"):
        code = "\n".join(ln.split("//")[0] for ln in p.read_text(encoding="utf-8", errors="replace").splitlines())
        if "target-cpu=native" in code.replace(" ", ""):
            err(f"{p.relative_to(root)}: target-cpu=native 금지 (C5-10)")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", required=True)
    ap.add_argument("--boundary", required=True)
    ap.add_argument("--harness", required=True)
    a = ap.parse_args()
    root = Path(a.root)
    boundary = a.boundary.split()
    harness = a.harness.split()

    ws = root / "Cargo.toml"
    wsm = load(ws) if ws.exists() else None
    check_baseline(root, wsm)
    check_native(root)
    if wsm is None:
        err("워크스페이스 Cargo.toml 이 없습니다 — 경계 크레이트를 검사할 수 없습니다 (M0 체크리스트)")
        return report()

    for name in boundary:
        mpath = root / "crates" / name / "Cargo.toml"
        if not mpath.exists():
            err(f"경계 크레이트가 없습니다: crates/{name}")
            continue
        m = load(mpath)
        deps_seen: set[str] = set()
        for table, deps in dep_tables(m, ("dependencies", "build-dependencies")):
            for dname, spec in deps.items():
                pkg = spec.get("package", dname) if isinstance(spec, dict) else dname
                is_path = isinstance(spec, dict) and "path" in spec
                if pkg in harness:
                    err(f"{name}: 하네스 크레이트 {pkg} 는 [{table}] 에 올 수 없습니다 (dev-dependencies 만)")
                elif pkg not in boundary or not is_path:
                    err(f"{name}: 외부 의존 [{table}] {dname} — 경계 안은 외부 크레이트 0 (C5-01, R8)")
                else:
                    deps_seen.add(pkg)
        for e in sorted(deps_seen - ALLOWED_EDGES.get(name, set())):
            err(f"{name} → {e}: 허용되지 않는 의존 방향 (ffi → module → core, C5-02)")

        lib = root / "crates" / name / "src" / "lib.rs"
        src = lib.read_text(encoding="utf-8", errors="replace") if lib.exists() else ""
        if not lib.exists():
            err(f"{name}: src/lib.rs 가 없습니다")
        if name in ("jamulsoe-core", "jamulsoe-module") and "#![forbid(unsafe_code)]" not in src:
            err(f"{name}: #![forbid(unsafe_code)] 가 없습니다 (C5-03, R6)")
        if name == "jamulsoe-core" and "#![no_std]" not in src:
            err(f"{name}: #![no_std] 가 없습니다 (C5-03)")
        if name == "jamulsoe-ffi":
            ctype = m.get("lib", {}).get("crate-type", [])
            if "cdylib" not in ctype:
                err(f"{name}: crate-type 에 cdylib 이 없습니다 (C5-07)")
            if "staticlib" in ctype:
                err(f"{name}: staticlib 은 검증 대상이 아닙니다 (C5-07)")

    oracle = root / "crates" / "jamulsoe-oracle" / "Cargo.toml"
    if oracle.exists():
        for table, deps in dep_tables(load(oracle), ("dependencies", "dev-dependencies", "build-dependencies")):
            for dname, spec in deps.items():
                pkg = spec.get("package", dname) if isinstance(spec, dict) else dname
                if pkg in boundary:
                    err(f"jamulsoe-oracle: 경계 크레이트 {pkg} 를 의존합니다 [{table}] — 독립성 위반 (.agents/INDEPENDENCE.md)")

    if not errors:
        oks.append("경계 크레이트 의존·속성")
    return report()


def report() -> int:
    for o in oks:
        print(f"  ✓ {o}")
    for e in errors:
        print(f"  ✗ {e}", file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())

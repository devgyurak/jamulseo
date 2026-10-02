/**
 * opencode 플러그인 — jamulsoe 게이트 **어댑터**.
 *
 * 규칙과 판정 로직은 여기 없다. 전부 scripts/hooks/ 에 있다.
 * 이 파일이 하는 일은 셋뿐이다:
 *   1. opencode 의 도구 인자를 공통 훅의 입력 형태({tool_input: {...}})로 변환
 *   2. scripts/hooks/* 실행
 *   3. 보호 검사의 모든 비정상 종료를 opencode 의 차단(throw)으로 변환 (fail-closed)
 */

const toToolInput = (args = {}) => ({
  file_path: args.filePath ?? args.path ?? args.file_path,
  content: args.content ?? args.new_content ?? args.text,
  old_string: args.oldString ?? args.old_string,
  new_string: args.newString ?? args.new_string,
  replace_all: args.replaceAll ?? args.replace_all,
  edits: args.edits,
});

export const JamulsoeGates = async ({ $, directory }) => {
  const hook = (name) => `${directory}/scripts/hooks/${name}.sh`;
  const isEdit = (tool) => tool === "write" || tool === "edit";

  return {
    /**
     * 도구 실행 전 — 보호 경로 판정. **경로만 넘기면 안 된다.**
     * 공통 구현은 "현재 내용에 편집을 적용한 결과"로 판정하므로 편집 인자를 그대로 전달한다
     * (경로만 넘기면 ADR 제안→채택 같은 짧은 치환을 놓친다).
     */
    "tool.execute.before": async (input, output) => {
      if (!isEdit(input.tool)) return;
      const payload = JSON.stringify({ tool_input: toToolInput(output?.args) });
      const res = await $`${hook("guard-protected")}`.stdin(payload).quiet().nothrow();
      if (res.exitCode !== 0) {
        throw new Error(res.stderr?.toString() || `보호 검사 실패 (exit ${res.exitCode})`);
      }
    },

    /** 도구 실행 후 — 반패턴 경고 + rustfmt·clippy·GWT (경고만) */
    "tool.execute.after": async (input, output) => {
      if (!isEdit(input.tool)) return;
      const payload = JSON.stringify({ tool_input: toToolInput(output?.args) });
      for (const name of ["guard-antipatterns", "post-edit"]) {
        const res = await $`${hook(name)}`.stdin(payload).quiet().nothrow();
        if (res.stderr?.length) console.warn(res.stderr.toString().trim());
      }
    },

    /** 세션 시작 — 컨텍스트 주입 */
    "session.start": async () => {
      const res = await $`${hook("session-context")}`.quiet().nothrow();
      if (res.stdout?.length) console.log(res.stdout.toString());
    },
  };
};

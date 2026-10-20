import MagicString from "magic-string";
import { RolldownMagicString } from "rolldown";
import { parseAst } from "rolldown/parseAst";
import { describe, expect, it, vi } from "vitest";
import { wrapTestModuleBody } from "../../discourse/lib/wrap-test-module-body.mjs";
import discourseWrapTestModules, {
  testModuleIdsFor,
} from "./discourse-wrap-test-modules.js";

const basePath = "discourse/plugins/poll/";

function transform(code, file, testModules = [file]) {
  const { handler } = discourseWrapTestModules({
    testModuleIds: testModuleIdsFor(basePath, testModules),
  }).transform;
  return (
    handler.call({ parse: parseAst }, code, `${basePath}${file}`)?.code ?? null
  );
}

describe("discourse-wrap-test-modules", () => {
  it("defers registration and awaits only the selected test module", async () => {
    const register = vi.fn();
    vi.stubGlobal("registerTest", register);
    try {
      const modules = [];
      for (const name of ["first", "second"]) {
        const code = transform(
          `await Promise.resolve(); registerTest("${name}");`,
          `unit/${name}-test.js`
        );
        modules.push(
          await import(
            /* @vite-ignore */ `data:text/javascript,${encodeURIComponent(code)}`
          )
        );
      }

      expect(register).not.toHaveBeenCalled();
      expect(modules[0].__discourseTestModule).toBe(true);
      await modules[0].default();
      expect(register).toHaveBeenCalledExactlyOnceWith("first");
    } finally {
      vi.unstubAllGlobals();
    }
  });

  it("keeps imports outside the wrapper with both build systems' editors", () => {
    const code =
      'import x from "./x";\nconst label = "zażółć 🎉";\nx(label);\nimport y from "./y";\ny();';
    const { body } = parseAst(code);
    const outputs = [MagicString, RolldownMagicString].map((Editor) => {
      const magic = new Editor(code);
      wrapTestModuleBody(body, magic);
      return magic.toString();
    });

    expect(outputs[0]).toBe(outputs[1]);
    expect(parseAst(outputs[0]).body.map((node) => node.type)).toEqual([
      "ImportDeclaration",
      "ImportDeclaration",
      "ExportDefaultDeclaration",
    ]);
  });

  it("rejects exported tests with guidance to move shared helpers", () => {
    expect(() =>
      transform("export function helper() {}", "unit/poll-test.js")
    ).toThrow(/Test modules cannot contain exports.*separate helper module/);
  });

  it("leaves helpers and files outside the test entrypoint alone", () => {
    const code = "export function helper() {}";
    expect(transform(code, "helpers/example.js")).toBeNull();
    expect(transform(code, "unit/poll-test.js", [])).toBeNull();

    const { handler } = discourseWrapTestModules({
      testModuleIds: testModuleIdsFor(basePath),
    }).transform;
    expect(handler.call({}, code, `${basePath}unit/poll-test.js`)).toBeNull();
  });
});

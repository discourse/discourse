import MagicString from "magic-string";
import { RolldownMagicString } from "rolldown";
import { parseAst } from "rolldown/parseAst";
import { describe, expect, it } from "vitest";
import { wrapTestModuleBody } from "../../discourse/lib/wrap-test-module-body.mjs";
import discourseWrapTestModules, {
  testModuleIdsFor,
} from "./discourse-wrap-test-modules.js";

const basePath = "discourse/plugins/poll/";

// Stands in for the `this` a transform hook gets.
const context = { parse: parseAst };

function transform(code, file, testModules = [file]) {
  const { handler } = discourseWrapTestModules({
    testModuleIds: testModuleIdsFor(basePath, testModules),
  }).transform;
  return handler.call(context, code, `${basePath}${file}`)?.code ?? null;
}

describe("wrapTestModuleBody", () => {
  it("wraps the same way with rolldown's native magic string, which core's build uses", () => {
    const code =
      `import { test } from "qunit";\nconst label = "zażółć 🎉";\n` +
      `test(label, () => {});\nimport x from "./x";\nx();\n`;
    const { body } = parseAst(code);
    const magic = new MagicString(code);
    const native = new RolldownMagicString(code);

    wrapTestModuleBody(body, magic);
    wrapTestModuleBody(body, native);

    expect(native.toString()).toBe(magic.toString());
  });
});

describe("testModuleIdsFor", () => {
  it("returns nothing without a test entrypoint", () => {
    expect(testModuleIdsFor(basePath, undefined).size).toBe(0);
  });
});

describe("discourse-wrap-test-modules", () => {
  it("wraps the body of a test file after its imports", () => {
    const out = transform(
      `import { test } from "qunit";\nimport x from "./x";\ntest("a", () => x());`,
      "unit/poll-test.js"
    );

    expect(out).toBe(
      `import { test } from "qunit";\nimport x from "./x";\n` +
        `export default async function () {\n\ntest("a", () => x());\n}\n` +
        `export const __discourseTestModule = true;\n`
    );
  });

  it("wraps a test file without imports", () => {
    expect(transform(`test("a", () => {});`, "unit/poll-test.js")).toBe(
      `\nexport default async function () {\ntest("a", () => {});\n}\n` +
        `export const __discourseTestModule = true;\n`
    );
  });

  it("moves imports that follow the body ahead of the wrapper", () => {
    // As in a `.js.es6` file, which gets a deprecation import appended
    const out = transform(
      `import { test } from "qunit";\ntest("a", () => {});\n` +
        `import deprecated from "discourse/lib/deprecated";\ndeprecated("es6");\n`,
      "unit/poll-test.js"
    );

    expect(out).toBe(
      `import { test } from "qunit";import deprecated from "discourse/lib/deprecated";\n` +
        `export default async function () {\n\ntest("a", () => {});\n\ndeprecated("es6");\n\n}\n` +
        `export const __discourseTestModule = true;\n`
    );
  });

  it.each([
    "export function helper() {}",
    "export default function helper() {}",
    'export { helper } from "./helper";',
    'export * from "./helper";',
    "export {};",
  ])("rejects exports with helper migration guidance: %s", (statement) => {
    expect(() =>
      transform(`test("a", () => {});\n${statement}`, "unit/poll-test.js")
    ).toThrow(
      "Test modules cannot contain exports. Move shared helpers into a separate helper module and import them."
    );
  });

  it("leaves helpers listed in the entrypoint alone", () => {
    expect(
      transform(`export function freeze() {}`, "helpers/freeze-time.js")
    ).toBeNull();
  });

  it("leaves modules outside the test entrypoint alone", () => {
    expect(
      transform(`test("a", () => {});`, "unit/poll-test.js", [])
    ).toBeNull();
  });

  it("leaves theme tests eager when there is no test entrypoint", () => {
    const { handler } = discourseWrapTestModules({
      testModuleIds: testModuleIdsFor("theme-1/", undefined),
    }).transform;

    expect(
      handler.call(
        context,
        'test("theme", () => {}); export const helper = true;',
        "theme-1/unit/theme-test.js"
      )
    ).toBeNull();
  });
});

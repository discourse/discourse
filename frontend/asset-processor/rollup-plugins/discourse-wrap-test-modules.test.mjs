import { parseAst } from "rolldown/parseAst";
import { describe, expect, it } from "vitest";
import discourseWrapTestModules, {
  testModuleIdsFor,
} from "./discourse-wrap-test-modules.js";

const basePath = "discourse/plugins/poll/";

let warnings;

// Stands in for the `this` a transform hook gets.
const context = { parse: parseAst, warn: (message) => warnings.push(message) };

function transform(code, file, testModules = [file]) {
  warnings = [];
  const { handler } = discourseWrapTestModules({
    testModuleIds: testModuleIdsFor(basePath, testModules),
  }).transform;
  return handler.call(context, code, `${basePath}${file}`)?.code ?? null;
}

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
        `export default function () {\n\ntest("a", () => x());\n}\n` +
        `export const __discourseTestModule = true;\n`
    );
  });

  it("wraps a test file without imports", () => {
    expect(transform(`test("a", () => {});`, "unit/poll-test.js")).toBe(
      `\nexport default function () {\ntest("a", () => {});\n}\n` +
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
        `export default function () {\n\ntest("a", () => {});\n\ndeprecated("es6");\n\n}\n` +
        `export const __discourseTestModule = true;\n`
    );
  });

  it("leaves a test file with exports alone, with a warning", () => {
    expect(
      transform(
        `test("a", () => {});\nexport function helper() {}`,
        "unit/poll-test.js"
      )
    ).toBeNull();
    expect(warnings).toHaveLength(1);
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
});

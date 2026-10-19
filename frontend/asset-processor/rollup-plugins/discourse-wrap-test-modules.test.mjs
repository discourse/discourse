import { parseAst } from "rolldown/parseAst";
import { describe, expect, it } from "vitest";
import discourseWrapTestModules from "./discourse-wrap-test-modules.js";

const basePath = "discourse/plugins/poll/";

// Stands in for the `this` a transform hook gets.
const context = { parse: parseAst };

function transform(code, file, testModules = [file]) {
  const { handler } = discourseWrapTestModules({
    basePath,
    testModules,
  }).transform;
  return handler.call(context, code, `${basePath}${file}`)?.code ?? null;
}

describe("discourse-wrap-test-modules", () => {
  it("wraps the body of a test file after its imports", () => {
    const out = transform(
      `import { test } from "qunit";\nimport x from "./x";\ntest("a", () => x());`,
      "unit/poll-test.js"
    );

    expect(out).toBe(
      `import { test } from "qunit";\nimport x from "./x";\n` +
        `export default function () {\n\ntest("a", () => x());\n}\n`
    );
  });

  it("wraps a test file without imports", () => {
    expect(transform(`test("a", () => {});`, "unit/poll-test.js")).toBe(
      `\nexport default function () {\ntest("a", () => {});\n}\n`
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
});

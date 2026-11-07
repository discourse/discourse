import { rolldown as rollup } from "rolldown";
import { expect, it } from "vitest";
import wrapTestModules from "../../discourse/lib/wrap-test-modules-plugin.mjs";
import discourseTestModules from "./discourse-test-modules.js";

it("test registrations wait for the selected module loader", async () => {
  const basePath = "discourse/plugins/chat/";
  const modules = {
    [`${basePath}unit/example-test.js`]:
      'import { value } from "./helper.js"; globalThis.__filePlanRegistrations.push(value);',
    [`${basePath}unit/helper.js`]: 'export const value = "selected";',
  };
  const bundle = await rollup({
    input: `${basePath}unit/example-test.js`,
    plugins: [
      {
        name: "fixture-modules",
        resolveId(source, importer) {
          return source.startsWith(".")
            ? `${importer.slice(0, importer.lastIndexOf("/"))}/${source.slice(2)}`
            : source;
        },
        load(id) {
          return modules[id];
        },
      },
      discourseTestModules({ basePath, modules: ["unit/example-test.js"] }),
    ],
  });
  try {
    const { output } = await bundle.generate({ format: "es" });
    globalThis.__filePlanRegistrations = [];
    const loaded = await import(
      `data:text/javascript;base64,${Buffer.from(output[0].code).toString("base64")}`
    );

    expect(globalThis.__filePlanRegistrations).toEqual([]);
    loaded.default();
    expect(globalThis.__filePlanRegistrations).toEqual(["selected"]);
  } finally {
    await bundle.close();
    delete globalThis.__filePlanRegistrations;
  }
});

it("core test statements wait for selection regardless of import position", async () => {
  const source = `
    globalThis.__filePlanExecutions = ["before"];
    import { first } from "fixture-dependency";
    globalThis.__filePlanExecutions.push(first);
    import { second } from "fixture-dependency";
    globalThis.__filePlanExecutions.push(second);
  `;
  const bundle = await rollup({
    input: "/virtual/tests/fixture-test.js",
    plugins: [
      {
        name: "isolation-fixture",
        resolveId(id) {
          return id;
        },
        load(id) {
          return id === "fixture-dependency"
            ? 'export const first = "between"; export const second = "after";'
            : source;
        },
      },
      wrapTestModules(),
    ],
  });
  try {
    const { output } = await bundle.generate({ format: "es" });
    const fixture = await import(
      `data:text/javascript;base64,${Buffer.from(output[0].code).toString("base64")}`
    );

    expect(globalThis.__filePlanExecutions).toBeUndefined();
    fixture.default();
    expect(globalThis.__filePlanExecutions).toEqual([
      "before",
      "between",
      "after",
    ]);
  } finally {
    await bundle.close();
    delete globalThis.__filePlanExecutions;
  }
});

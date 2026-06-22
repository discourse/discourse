/* eslint-disable qunit/require-expect */
import { transformSync } from "@babel/core";
import { expect, test } from "vitest";
import InjectCustomizationSource from "./inject-customization-source.js";

function compile(input, source) {
  return transformSync(input, {
    configFile: false,
    plugins: [[InjectCustomizationSource, { source }]],
  }).code;
}

function countOccurrences(haystack, needle) {
  return haystack.split(needle).length - 1;
}

test("appends a plugin descriptor to withPluginApi calls", () => {
  const code = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     withPluginApi((api) => api.registerBlock(Foo));`,
    { type: "plugin", name: "chat" }
  );

  expect(code).toContain(
    '[Symbol.for("discourse:customization-source")]: true'
  );
  expect(code).toContain('type: "plugin"');
  expect(code).toContain('name: "chat"');
});

test("appends a theme descriptor to apiInitializer calls", () => {
  const code = compile(
    `import { apiInitializer } from "discourse/lib/api";
     export default apiInitializer((api) => api.registerBlock(Foo));`,
    { type: "theme", id: 42 }
  );

  expect(code).toContain(
    '[Symbol.for("discourse:customization-source")]: true'
  );
  expect(code).toContain('type: "theme"');
  expect(code).toContain("id: 42");
});

test("handles aliased imports", () => {
  const code = compile(
    `import { withPluginApi as wpa } from "discourse/lib/plugin-api";
     wpa((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  expect(code).toContain(
    '[Symbol.for("discourse:customization-source")]: true'
  );
  expect(code).toContain('name: "chat"');
});

test("does not rewrite functions that are not source-aware entry points", () => {
  const code = compile(
    `import { somethingElse } from "discourse/lib/plugin-api";
     somethingElse((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  expect(code).not.toContain("discourse:customization-source");
});

test("does not rewrite a same-named local that is not the imported binding", () => {
  const code = compile(
    `function withPluginApi() {}
     withPluginApi();`,
    { type: "plugin", name: "chat" }
  );

  expect(code).not.toContain("discourse:customization-source");
});

test("does not rewrite imports from a different module", () => {
  const code = compile(
    `import { withPluginApi } from "somewhere/else";
     withPluginApi((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  expect(code).not.toContain("discourse:customization-source");
});

test("is idempotent across repeated transforms", () => {
  const source = { type: "plugin", name: "chat" };
  const once = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     withPluginApi((api) => {});`,
    source
  );
  const twice = compile(once, source);

  expect(countOccurrences(twice, "discourse:customization-source")).toBe(1);
});

test("is a no-op when no source is provided", () => {
  const code = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     withPluginApi((api) => {});`,
    undefined
  );

  expect(code).not.toContain("discourse:customization-source");
});

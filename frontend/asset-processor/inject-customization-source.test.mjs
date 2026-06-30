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

const DESCRIPTOR_KEY = '[Symbol.for("discourse:customization-source")]: true';

test("shadows withPluginApi with a descriptor-appending wrapper", () => {
  const code = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     withPluginApi((api) => api.registerBlock(Foo));`,
    { type: "plugin", name: "chat" }
  );

  // import repointed to the hidden raw binding
  expect(code).toContain(
    "import { withPluginApi as _customizationSource$withPluginApi }"
  );
  // wrapper under the original name, forwarding to the raw binding + descriptor
  expect(code).toContain("function withPluginApi(...args)");
  expect(code).toContain("_customizationSource$withPluginApi(...args,");
  expect(code).toContain(DESCRIPTOR_KEY);
  expect(code).toContain('type: "plugin"');
  expect(code).toContain('name: "chat"');
  // the call site is left as a call to `withPluginApi` (now the wrapper); babel
  // may reprint `(api) =>` as `api =>`, so match loosely.
  expect(code).toMatch(
    /withPluginApi\(\(?api\)? *=> *api\.registerBlock\(Foo\)\)/
  );
});

test("shadows apiInitializer with a theme descriptor", () => {
  const code = compile(
    `import { apiInitializer } from "discourse/lib/api";
     export default apiInitializer((api) => api.registerBlock(Foo));`,
    { type: "theme", id: 42 }
  );

  expect(code).toContain(
    "import { apiInitializer as _customizationSource$apiInitializer }"
  );
  expect(code).toContain("function apiInitializer(...args)");
  expect(code).toContain('type: "theme"');
  expect(code).toContain("id: 42");
});

test("handles aliased imports (wrapper under the alias)", () => {
  const code = compile(
    `import { withPluginApi as wpa } from "discourse/lib/plugin-api";
     wpa((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  expect(code).toContain(
    "import { withPluginApi as _customizationSource$withPluginApi }"
  );
  expect(code).toContain("function wpa(...args)");
  expect(code).toContain(DESCRIPTOR_KEY);
});

test("attributes a stored alias and a callback reference via the shadow", () => {
  const code = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     const w = withPluginApi;
     register(withPluginApi);
     w((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  // The only `withPluginApi` binding is the wrapper, so both the stored alias and
  // the callback reference capture the descriptor-appending wrapper.
  expect(code).toContain("function withPluginApi(...args)");
  expect(code).toContain("const w = withPluginApi;");
  expect(code).toContain("register(withPluginApi)");
  // the raw import is hidden behind the prefix; user code can't reach it unwrapped
  expect(code).toContain(
    "import { withPluginApi as _customizationSource$withPluginApi }"
  );
});

test("does not touch non-entry imports", () => {
  const code = compile(
    `import { somethingElse } from "discourse/lib/plugin-api";
     somethingElse((api) => {});`,
    { type: "plugin", name: "chat" }
  );

  expect(code).not.toContain("discourse:customization-source");
  expect(code).not.toContain("function somethingElse");
});

test("does not touch a same-named local that is not the import", () => {
  const code = compile(
    `function withPluginApi() {}
     withPluginApi();`,
    { type: "plugin", name: "chat" }
  );

  expect(code).not.toContain("discourse:customization-source");
});

test("does not touch imports from a different module", () => {
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

  expect(countOccurrences(twice, "function withPluginApi(...args)")).toBe(1);
  expect(countOccurrences(twice, DESCRIPTOR_KEY)).toBe(1);
});

test("is a no-op when no source is provided", () => {
  const code = compile(
    `import { withPluginApi } from "discourse/lib/plugin-api";
     withPluginApi((api) => {});`,
    undefined
  );

  expect(code).not.toContain("discourse:customization-source");
  expect(code).not.toContain("function withPluginApi");
});

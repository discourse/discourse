/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import { privateVirtualImports } from "./rollup-virtual-imports.js";

test("attributed plugin-api module wraps withPluginApi for a plugin", () => {
  const code = privateVirtualImports["virtual:attributed-plugin-api"]({
    pluginName: "chat",
  });

  expect(code).toContain(
    'import { _INTERNAL_SOURCE_KEY } from "discourse/lib/api";'
  );
  expect(code).toContain(
    'import { withPluginApi as _withPluginApi } from "discourse/lib/plugin-api";'
  );
  expect(code).toContain('Object.freeze({"type":"plugin","name":"chat"})');
  expect(code).toContain("export function withPluginApi(...args)");
  expect(code).toContain("[_INTERNAL_SOURCE_KEY]: SOURCE");
  expect(code).toContain("return _withPluginApi(...args);");
});

test("attributed api-initializer module wraps apiInitializer for a theme", () => {
  const code = privateVirtualImports["virtual:attributed-api-initializer"]({
    themeId: 42,
  });

  expect(code).toContain(
    'import { apiInitializer as _apiInitializer } from "discourse/lib/api";'
  );
  expect(code).toContain('Object.freeze({"type":"theme","id":42})');
  expect(code).toContain("export function apiInitializer(...args)");
  expect(code).toContain("return _apiInitializer(...args);");
});

test("the source lands on opts, after the legacy version argument", () => {
  const code = privateVirtualImports["virtual:attributed-plugin-api"]({
    pluginName: "chat",
  });

  expect(code).toContain('typeof args[0] === "string" ? 2 : 1');
  expect(code).toContain(
    "args[optsIndex] = { ...args[optsIndex], [_INTERNAL_SOURCE_KEY]: SOURCE };"
  );
});

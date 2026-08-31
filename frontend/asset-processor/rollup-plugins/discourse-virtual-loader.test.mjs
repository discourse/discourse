/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import discourseVirtualLoader from "./discourse-virtual-loader.js";

const basePath = "discourse/plugins/chat/";
const PLUGIN_API_WRAPPER = `\0${basePath}virtual:attributed-plugin-api`;
const API_INITIALIZER_WRAPPER = `\0${basePath}virtual:attributed-api-initializer`;

function loader(isTheme = false) {
  return discourseVirtualLoader({
    basePath,
    entrypoints: {},
    opts: { pluginName: "chat" },
    isTheme,
  });
}

test("redirects the api entry modules to their attributed wrappers", () => {
  const { resolveId } = loader();

  expect(resolveId("discourse/lib/plugin-api", `${basePath}some-module`)).toBe(
    PLUGIN_API_WRAPPER
  );
  expect(resolveId("discourse/lib/api", `${basePath}some-module`)).toBe(
    API_INITIALIZER_WRAPPER
  );
});

test("leaves the wrappers' own imports of the real modules alone", () => {
  const { resolveId } = loader();

  for (const wrapper of [PLUGIN_API_WRAPPER, API_INITIALIZER_WRAPPER]) {
    expect(resolveId("discourse/lib/plugin-api", wrapper)).toBeUndefined();
    expect(resolveId("discourse/lib/api", wrapper)).toBeUndefined();
  }
});

test("the wrappers cannot be imported by name", () => {
  for (const isTheme of [false, true]) {
    const { resolveId } = loader(isTheme);

    expect(
      resolveId("virtual:attributed-plugin-api", `${basePath}some-module`)
    ).toBeUndefined();
    expect(
      resolveId("virtual:attributed-api-initializer", `${basePath}some-module`)
    ).toBeUndefined();
  }
});

test("plugin builds can load the wrappers but not virtual:theme", () => {
  const { load } = loader();

  expect(load(PLUGIN_API_WRAPPER)).toContain("_INTERNAL_SOURCE_KEY");
  expect(load(`${basePath}virtual:theme`)).toBeUndefined();
});

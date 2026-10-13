/* eslint-disable qunit/require-expect */
import { expect, test } from "vitest";
import discourseVirtualLoader from "./discourse-virtual-loader.js";

const basePath = "discourse/plugins/chat/";
const PLUGIN_API_WRAPPER = `\0${basePath}virtual:attributed-plugin-api`;
const API_INITIALIZER_WRAPPER = `\0${basePath}virtual:attributed-api-initializer`;

function loader(isTheme = false, entrypoints = {}, opts = {}) {
  return discourseVirtualLoader({
    basePath,
    entrypoints,
    opts: { pluginName: "chat", ...opts },
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

test("loads a route bundle from its own entrypoint, not another with the same name", () => {
  const { load } = loader(
    false,
    {
      main: { modules: ["discourse/routes/chat.js"] },
      admin: { modules: ["discourse/routes/admin-plugins/show/hooks.js"] },
    },
    {
      frontendConfig: { staticModules: true },
      routeTables: {
        bundleByRoute: {
          chat: "default",
          "admin-plugins.show.hooks": "default",
        },
      },
    }
  );

  expect(load(`${basePath}virtual:route:main:default`)).toContain(
    '"discourse/routes/chat":'
  );
  expect(load(`${basePath}virtual:route:admin:default`)).toContain(
    '"discourse/routes/admin-plugins/show/hooks":'
  );
});

test("a route bundle missing from the named entrypoint is an error", () => {
  const { load } = loader(
    false,
    { main: { modules: ["discourse/routes/chat.js"] } },
    {
      frontendConfig: { staticModules: true },
      routeTables: { bundleByRoute: { chat: "default" } },
    }
  );

  expect(() => load(`${basePath}virtual:route:admin:default`)).toThrow(
    /No route bundle for "default" in the admin entrypoint/
  );
});

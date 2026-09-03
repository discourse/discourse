import { describe, expect, it } from "vitest";
import rollupVirtualImports, {
  privateVirtualImports,
  routeNamesFor,
} from "./rollup-virtual-imports";

function entrypoint(moduleFilenames, opts = {}, extra) {
  return rollupVirtualImports["virtual:entrypoint"](
    moduleFilenames,
    {
      pluginName: "chat",
      ...opts,
    },
    { entrypointName: "main", ...extra }
  );
}

const MODULES = [
  "discourse/components/chat-channel.gjs",
  "discourse/services/chat.js",
  "discourse/models/channel.js",
  "discourse/adapters/chat.js",
  "discourse/initializers/chat-setup.js",
  "discourse/api-initializers/chat.js",
  "discourse/pre-initializers/chat-early.js",
  "discourse/chat-route-map.js",
  "discourse/connectors/user-menu/chat.gjs",
  "discourse/routes/chat/channel.js",
  "discourse/controllers/chat/channel.js",
  "discourse/templates/chat/channel.hbs",
  "discourse/lib/chat-utils.js",
  "discourse/helpers/format-chat-date.js",
];

describe("virtual:entrypoint", () => {
  describe("without staticModules", () => {
    it("eagerly imports every module and exports one object under both names", () => {
      const output = entrypoint(MODULES);

      for (const filename of MODULES) {
        // Connectors keep their extension; everything else is stripped.
        const importPath = filename.includes("/connectors/")
          ? filename
          : filename.replace(/\.\w+$/, "");
        expect(output, filename).toContain(`from "./${importPath}"`);
      }

      expect(output).toContain("export { compatModules };");
      expect(output).toContain("export default compatModules;");
      expect(output).not.toContain("sharedModules");
    });

    it("skips type declarations and warns about unsupported files", () => {
      const output = entrypoint([
        "discourse/lib/types.d.ts",
        "discourse/lib/notes.md",
        "discourse/services/chat.js",
      ]);

      expect(output).not.toContain("types.d.ts");
      expect(output).toContain("Unsupported file type: discourse/lib/notes.md");
      expect(output).toContain('from "./discourse/services/chat"');
    });
  });

  describe("with staticModules", () => {
    const output = entrypoint(MODULES, {
      frontendConfig: {
        staticModules: true,
        sharedModules: [
          "discourse/components/chat-channel.gjs",
          "discourse/models/channel.js",
        ],
      },
    });

    const compatModules = output.slice(
      output.indexOf("const compatModules"),
      output.indexOf("const sharedModules")
    );
    const sharedModules = output.slice(output.indexOf("const sharedModules"));

    it("registers everything Discourse resolves by name", () => {
      for (const name of [
        "discourse/services/chat",
        "discourse/models/channel",
        "discourse/adapters/chat",
        "discourse/initializers/chat-setup",
        "discourse/api-initializers/chat",
        "discourse/pre-initializers/chat-early",
        "discourse/chat-route-map",
        "discourse/connectors/user-menu/chat",
      ]) {
        expect(compatModules, name).toContain(`"${name}":`);
      }
    });

    it("does not register routes, controllers or route templates", () => {
      for (const name of [
        "discourse/routes/chat/channel",
        "discourse/controllers/chat/channel",
        "discourse/templates/chat/channel",
      ]) {
        expect(compatModules, name).not.toContain(`"${name}":`);
      }
    });

    it("leaves invokables and lib code to be statically imported", () => {
      // Registering these would stop them tree-shaking.
      expect(compatModules).not.toContain(
        '"discourse/helpers/format-chat-date"'
      );
      expect(compatModules).not.toContain('"discourse/lib/chat-utils"');
      expect(compatModules).not.toContain(
        '"discourse/components/chat-channel"'
      );
    });

    it("exports only the declared sharedModules as the cross-bundle API", () => {
      expect(sharedModules).toContain('"discourse/components/chat-channel":');
      expect(sharedModules).toContain('"discourse/models/channel":');
      expect(sharedModules).not.toContain('"discourse/services/chat":');
      expect(output).toContain("export default sharedModules;");
    });

    it("imports a module shared and registered only once", () => {
      // `discourse/models/channel` is both eager and shared.
      const imports = output
        .split("\n")
        .filter((line) => line.includes('from "./discourse/models/channel"'));
      expect(imports).toHaveLength(1);
    });

    it("does not import modules which are neither eager nor shared", () => {
      expect(output).not.toContain('from "./discourse/lib/chat-utils"');
      expect(output).not.toContain(
        'from "./discourse/helpers/format-chat-date"'
      );
    });

    it("emits no routes export when nothing is split", () => {
      expect(output).toContain("export const routes = [\n];");
    });
  });

  describe("test entrypoint", () => {
    const TEST_MODULES = [
      "acceptance/chat-message-test.gjs",
      "components/chat-channel-test.gjs",
      "unit/lib/chat-utils-test.js",
      "unit/services/chat-test.js",
      "integration/components/user-menu/chat-test.gjs",
      "helpers/chat-fixtures.js",
    ];

    it("eagerly imports every module despite staticModules", () => {
      const output = entrypoint(
        TEST_MODULES,
        { frontendConfig: { staticModules: true, sharedModules: [] } },
        { entrypointName: "test" }
      );

      for (const filename of TEST_MODULES) {
        const importPath = filename.replace(/\.\w+$/, "");
        expect(output, filename).toContain(`from "./${importPath}"`);
      }

      expect(output).toContain("export default compatModules;");
      expect(output).not.toContain("sharedModules");
    });

    it("still tree-shakes the same modules for a non-test entrypoint", () => {
      const output = entrypoint(
        TEST_MODULES,
        { frontendConfig: { staticModules: true, sharedModules: [] } },
        { entrypointName: "main" }
      );

      expect(output).not.toContain('from "./components/chat-channel-test"');
      expect(output).not.toContain('from "./unit/lib/chat-utils-test"');
    });
  });

  describe("route bundles", () => {
    const ROUTE_MODULES = [
      "discourse/routes/chat.js",
      "discourse/routes/chat/channel.js",
      "discourse/controllers/chat/channel.js",
      "discourse/templates/chat/channel.hbs",
      "discourse/routes/chat/visualizer.js",
      "discourse/templates/chat/visualizer.hbs",
      "discourse/routes/browse.js",
      "discourse/services/chat.js",
      "discourse/templates/connectors/user-menu/chat.hbs",
      "discourse/templates/components/chat-message.hbs",
      // Chat really has these: components in a directory called `routes`.
      "discourse/components/chat/routes/channel.gjs",
    ];

    const frontendConfig = { staticModules: true };

    // `chat.visualizer` names its own bundle, so it is not swept into `chat`.
    const routeTables = {
      bundleByRoute: {
        chat: "chat",
        "chat.channel": "chat",
        "chat.visualizer": "visualizer",
      },
    };

    const output = entrypoint(ROUTE_MODULES, { frontendConfig, routeTables });

    it("groups routes into a bundle per declared name", () => {
      expect(output).toContain(
        `{ names: ["chat.visualizer"], load: () => import("virtual:route:main:visualizer") },`
      );
      expect(output).toContain(
        `{ names: ["chat","chat.channel"], load: () => import("virtual:route:main:chat") },`
      );
    });

    it("puts an implicit index route in its parent's bundle", () => {
      const withIndex = entrypoint(
        [...ROUTE_MODULES, "discourse/routes/chat/index.js"],
        { frontendConfig, routeTables }
      );

      expect(withIndex).toContain(
        `{ names: ["chat","chat.channel","chat.index"], load: () => import("virtual:route:main:chat") },`
      );
    });

    it("keeps a bundle name in one entrypoint clear of the same name in another", () => {
      // Both entrypoints put their unnamed routes in `default`, and each is built from its own
      // module list.
      const shared = { bundleByRoute: { chat: "default", admin: "default" } };

      const main = entrypoint(
        ["discourse/routes/chat.js"],
        { frontendConfig, routeTables: shared },
        { entrypointName: "main" }
      );
      const admin = entrypoint(
        ["discourse/routes/admin.js"],
        { frontendConfig, routeTables: shared },
        { entrypointName: "admin" }
      );

      expect(main).toContain(
        `{ names: ["chat"], load: () => import("virtual:route:main:default") },`
      );
      expect(admin).toContain(
        `{ names: ["admin"], load: () => import("virtual:route:admin:default") },`
      );
    });

    it("keeps split route files out of the eager set", () => {
      const compatModules = output.slice(
        output.indexOf("const compatModules"),
        output.indexOf("const sharedModules")
      );

      expect(compatModules).not.toContain('"discourse/routes/chat"');
      expect(compatModules).not.toContain('"discourse/routes/chat/channel"');
      expect(compatModules).not.toContain('"discourse/templates/chat/channel"');

      // A route no map names is not registered either.
      expect(compatModules).not.toContain('"discourse/routes/browse":');

      expect(compatModules).toContain('"discourse/services/chat":');
    });

    it("does not mistake connectors or component templates for routes", () => {
      expect(output).not.toContain('import("virtual:route:connectors');
      expect(output).not.toContain('import("virtual:route:components');
      expect(output).not.toContain('"connectors.user-menu.chat"');
      expect(output).not.toContain('"components.chat-message"');
    });

    it("only treats top-level routes/controllers/templates as routes", () => {
      const compatModules = output.slice(
        output.indexOf("const compatModules"),
        output.indexOf("const sharedModules")
      );

      expect(compatModules).not.toContain(
        '"discourse/components/chat/routes/channel"'
      );
      expect(output).not.toContain('import("virtual:route:channel")');
    });

    it("renders a route bundle as a plain module map", () => {
      const bundle = rollupVirtualImports["virtual:route"](
        ROUTE_MODULES,
        { pluginName: "chat", frontendConfig, routeTables },
        "chat"
      );

      expect(bundle).toContain('"discourse/routes/chat":');
      expect(bundle).toContain('"discourse/routes/chat/channel":');
      expect(bundle).toContain('"discourse/controllers/chat/channel":');
      expect(bundle).toContain('"discourse/templates/chat/channel":');
      expect(bundle).toContain("export default routeCompatModules;");

      // The separately-split child does not belong to the parent bundle.
      expect(bundle).not.toContain('"discourse/routes/chat/visualizer":');
    });
  });
});

describe("privateVirtualImports", () => {
  it("wraps withPluginApi for a plugin", () => {
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

  it("wraps apiInitializer for a theme", () => {
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

  it("puts the source on opts, after the legacy version argument", () => {
    const code = privateVirtualImports["virtual:attributed-plugin-api"]({
      pluginName: "chat",
    });

    expect(code).toContain('typeof args[0] === "string" ? 2 : 1');
    expect(code).toContain(
      "args[optsIndex] = { ...args[optsIndex], [_INTERNAL_SOURCE_KEY]: SOURCE };"
    );
  });
});

describe("routeNamesFor", () => {
  it("reports only the routes a module list backs", () => {
    const bundleByRoute = { chat: "default", "admin.hooks": "default" };

    expect([
      ...routeNamesFor(["discourse/routes/chat.js"], bundleByRoute),
    ]).toEqual(["chat"]);
    expect([
      ...routeNamesFor(["discourse/templates/admin/hooks.hbs"], bundleByRoute),
    ]).toEqual(["admin.hooks"]);
    expect([
      ...routeNamesFor(["discourse/services/chat.js"], bundleByRoute),
    ]).toEqual([]);
  });
});

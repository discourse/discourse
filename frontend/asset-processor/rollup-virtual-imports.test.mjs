import { describe, expect, it } from "vitest";
import rollupVirtualImports from "./rollup-virtual-imports";

function entrypoint(moduleFilenames, opts = {}) {
  return rollupVirtualImports["virtual:entrypoint"](moduleFilenames, {
    pluginName: "chat",
    ...opts,
  });
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
        // Connectors are imported with their extension intact; everything else is stripped.
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
      frontend: {
        staticModules: true,
        sharedModules: [
          "discourse/components/chat-channel.gjs",
          "discourse/models/channel.js",
        ],
      },
    });

    const compatModules = output
      .slice(output.indexOf("const compatModules"), output.indexOf("const sharedModules"));
    const sharedModules = output.slice(output.indexOf("const sharedModules"));

    it("registers everything Discourse resolves by name", () => {
      for (const name of [
        "discourse/services/chat",
        "discourse/models/channel",
        "discourse/adapters/chat",
        "discourse/initializers/chat-setup",
        "discourse/api-initializers/chat",
        "discourse/pre-initializers/chat-early",
        // Plugins name their route maps `<something>-route-map`, and `mapRoutes` matches on the
        // suffix alone.
        "discourse/chat-route-map",
        // `.gjs` connectors keep their path; only `.hbs` connectors are rewritten under
        // `templates/connectors/`.
        "discourse/connectors/user-menu/chat",
        "discourse/routes/chat/channel",
        "discourse/controllers/chat/channel",
        "discourse/templates/chat/channel",
      ]) {
        expect(compatModules, name).toContain(`"${name}":`);
      }
    });

    it("leaves invokables and lib code to be statically imported", () => {
      // Components, helpers, modifiers and lib are reached through `.gjs` imports under
      // staticModules, so they must not be registered — that is what lets them tree-shake.
      expect(compatModules).not.toContain('"discourse/helpers/format-chat-date"');
      expect(compatModules).not.toContain('"discourse/lib/chat-utils"');
      expect(compatModules).not.toContain('"discourse/components/chat-channel"');
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

  describe("splitAtRoutes", () => {
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

    const frontend = {
      staticModules: true,
      splitAtRoutes: {
        "chat/visualizer": "chat.visualizer",
        "chat/*": "chat.*",
      },
    };

    const output = entrypoint(ROUTE_MODULES, { frontend });

    it("groups routes into a bundle per split base, nearest ancestor winning", () => {
      // `chat.visualizer` is split separately, so it must not be swept into the `chat` bundle.
      expect(output).toContain(
        `{ names: ["chat.visualizer"], load: () => import("virtual:route:chat.visualizer") },`
      );
      expect(output).toContain(
        `{ names: ["chat","chat.channel"], load: () => import("virtual:route:chat") },`
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

      // Unclaimed routes stay eager.
      expect(compatModules).toContain('"discourse/routes/browse":');
      expect(compatModules).toContain('"discourse/services/chat":');
    });

    it("does not mistake connectors or component templates for routes", () => {
      const compatModules = output.slice(
        output.indexOf("const compatModules"),
        output.indexOf("const sharedModules")
      );

      // Discourse nests these under `templates/`, unlike a core app. Treating them as routes
      // would give bundles named `connectors.*` / `components.*` and drop them from the
      // eager set.
      expect(compatModules).toContain(
        '"discourse/templates/connectors/user-menu/chat":'
      );
      expect(compatModules).toContain(
        '"discourse/templates/components/chat-message":'
      );
    });

    it("only treats top-level routes/controllers/templates as routes", () => {
      // `discourse/components/chat/routes/channel` is a component sitting in a directory called
      // `routes`. Matching `routes/` at any depth would make it a route named `channel`, and
      // register it eagerly instead of letting it be imported.
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
        { pluginName: "chat", frontend },
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

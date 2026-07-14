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
  "discourse/route-map.js",
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
        "discourse/route-map",
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
      expect(output).not.toContain('from "./discourse/helpers/format-chat-date"');
    });
  });
});

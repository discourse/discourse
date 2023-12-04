import fsx from "fs-extra";
import path from "path";
import walkSync from "walk-sync";

const { readJsonSync, writeJsonSync } = fsx;

const PluginFeatures = [
  "connectors/",
  "events/",
  "markdown-features/",
  "route-maps/",
];

function isPluginFeature(module) {
  for (const prefix of PluginFeatures) {
    // Things should already be in .js at this stage; we don't want .d.ts/.map
    if (module.startsWith(prefix) && module.endsWith(".js")) {
      return true;
    }
  }

  return false;
}

function normalizeFileExt(fileName) {
  return fileName.replace(/(?<!\.d)\.ts|\.gjs|\.gts$/, ".js");
}

// Loosely based on publicEntrypoints from @embroider/addon-dev
export default function exportPluginFeatures({ srcDir, destDir }) {
  return {
    name: "export-plugin-features",

    async buildStart() {
      this.addWatchFile(srcDir);

      const matches = walkSync(srcDir, {
        directories: false,
        globs: ["**/*.js", "**/*.ts", "**/*.gjs", "**/*.gts"],
      });

      for (const name of matches) {
        // the matched file, but with the extension swapped with .js
        const normalizedName = normalizeFileExt(name);

        if (isPluginFeature(normalizedName)) {
          this.emitFile({
            type: "chunk",
            id: path.join(srcDir, name),
            fileName: normalizedName,
          });
        }
      }
    },

    generateBundle(_, bundle) {
      const packageJson = readJsonSync("package.json");
      const originalExports = packageJson.exports;
      const exports =
        typeof originalExports === "string"
          ? { ".": originalExports }
          : { ...originalExports };

      for (const moduleName of Object.keys(exports)) {
        if (!moduleName.startsWith("./")) {
          // Other than ".", this would be illegal. Should we warn about it?
          continue;
        }

        const normalizedName = moduleName.slice(2) + ".js";

        if (isPluginFeature(normalizedName)) {
          // we'll add this back later, as needed
          delete exports[moduleName];
        }
      }

      for (const moduleName of Object.keys(bundle)) {
        if (isPluginFeature(moduleName)) {
          // without .js
          const entryName = "./" + moduleName.slice(0, -3);
          exports[entryName] = "./" + path.join(destDir, moduleName);
        }
      }

      const sortedExports = {};

      for (const moduleName of Object.keys(exports).sort()) {
        sortedExports[moduleName] = exports[moduleName];
      }

      const hasChanges =
        JSON.stringify(originalExports) !== JSON.stringify(sortedExports);

      if (hasChanges) {
        packageJson.exports = sortedExports;
        writeJsonSync("package.json", packageJson, { spaces: 2 });
      }
    },
  };
}

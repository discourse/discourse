import fsx from "fs-extra";
const { readJsonSync, writeJsonSync } = fsx;

const PluginFeatures = [
  "./connectors/",
  "./events/",
  "./markdown-features/",
  "./route-maps/",
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

export default function exportPluginFeatures() {
  return {
    name: "export-plugin-features",
    generateBundle(_, bundle) {
      const packageJson = readJsonSync("package.json");
      const originalExports = packageJson.exports;
      const exports = { ...originalExports };

      for (const moduleName of Object.keys(exports)) {
        if (isPluginFeature(moduleName)) {
          // we'll add this back later, as needed
          delete exports[moduleName];
        }
      }

      for (const moduleName of Object.keys(bundle)) {
        const qualifiedName = `./${moduleName}`;

        if (isPluginFeature(qualifiedName)) {
          // without .js
          const entryName = qualifiedName.slice(0, -3);
          exports[entryName] = `./dist/${moduleName}`;
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

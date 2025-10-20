import { federatedExportNameFor } from "./federated-modules-helper";

const SUPPORTED_FILE_EXTENSIONS = [".js", ".js.es6", ".hbs", ".gjs"];

const IS_CONNECTOR_REGEX = /(^|\/)connectors\//;

export default {
  "virtual:main": async (tree, { themeId }, basePath, context) => {
    let output = `const compatModules = {};`;

    if (themeId) {
      output += cleanMultiline(`
        import "virtual:init-settings";
      `);
    }

    let i = 1;
    for (const moduleFilename of Object.keys(tree)) {
      if (
        !SUPPORTED_FILE_EXTENSIONS.some((ext) => moduleFilename.endsWith(ext))
      ) {
        // Unsupported file type. Log a warning and skip
        output += `console.warn("[THEME ${themeId}] Unsupported file type: ${moduleFilename}");\n`;
        continue;
      }

      const filenameWithoutExtension = moduleFilename.replace(
        /\.[^\.]+(\.es6)?$/,
        ""
      );

      let compatModuleName = filenameWithoutExtension;

      if (moduleFilename.match(IS_CONNECTOR_REGEX)) {
        const isTemplate = moduleFilename.endsWith(".hbs");
        const isInTemplatesDirectory =
          moduleFilename.match(/(^|\/)templates\//);

        if (isTemplate && !isInTemplatesDirectory) {
          compatModuleName = compatModuleName.replace(
            IS_CONNECTOR_REGEX,
            "$1templates/connectors/"
          );
        } else if (!isTemplate && isInTemplatesDirectory) {
          compatModuleName = compatModuleName.replace(/^templates\//, "");
        }
      }

      const importPath = filenameWithoutExtension.match(IS_CONNECTOR_REGEX)
        ? moduleFilename
        : filenameWithoutExtension;
      output += `import * as Mod${i} from "./${importPath}";\n`;
      output += `compatModules["${compatModuleName}"] = Mod${i};\n\n`;

      const resolvedId = await context.resolve(
        `./${importPath}`,
        `${basePath}virtual:main`
      );
      const loadedModule = await context.load(resolvedId);

      const reexportPairs = loadedModule.exports.map((exportedName) => {
        return `${exportedName} as ${federatedExportNameFor(compatModuleName, exportedName)}`;
      });

      const isIndexModule =
        compatModuleName.endsWith("/index") &&
        !tree[moduleFilename.replace("/index", "")];

      if (isIndexModule) {
        loadedModule.exports.forEach((exportedName) => {
          const federatedExportName = federatedExportNameFor(
            compatModuleName.replace(/\/index$/, ""),
            exportedName
          );
          reexportPairs.push(`${exportedName} as ${federatedExportName}`);
        });
      }

      output += `export { ${reexportPairs.join(", ")} } from "./${importPath}";\n`;

      i += 1;
    }

    output += "export default compatModules;\n";

    return output;
  },
  "virtual:init-settings": (_, { themeId, settings }) => {
    return (
      `import { registerSettings } from "discourse/lib/theme-settings-store";\n\n` +
      `registerSettings(${themeId}, ${JSON.stringify(settings, null, 2)});\n`
    );
  },
  "virtual:theme": (_, { themeId }) => {
    return cleanMultiline(`
      import { getObjectForTheme } from "discourse/lib/theme-settings-store";

      export const settings = getObjectForTheme(${themeId});

      export function themePrefix(key) {
        return \`theme_translations.${themeId}.\${key}\`;
      }
    `);
  },
};

function cleanMultiline(str) {
  const lines = str.split("\n");

  if (lines.at(0).trim() === "") {
    lines.shift();
  }
  if (lines.at(-1).trim() === "") {
    lines.pop();
  }

  const minLeadingWhitspace = Math.min(
    ...lines.filter(Boolean).map((line) => line.match(/^\s*/)[0].length)
  );

  return lines.map((line) => line.slice(minLeadingWhitspace)).join("\n") + "\n";
}

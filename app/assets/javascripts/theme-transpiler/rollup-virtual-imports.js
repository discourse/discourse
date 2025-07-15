const SUPPORTED_FILE_EXTENSIONS = [".js", ".js.es6", ".hbs", ".gjs"];

export default {
  "virtual:main": (tree, { themeId }) => {
    let output = `
      import "virtual:init-settings";
    `;

    output += "const themeCompatModules = {};\n";

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

      if (moduleFilename.match(/(^|\/)connectors\//)) {
        const isTemplate = moduleFilename.endsWith(".hbs");
        const isInTemplatesDirectory =
          moduleFilename.match(/(^|\/)templates\//);

        if (isTemplate && !isInTemplatesDirectory) {
          compatModuleName = compatModuleName.replace(
            /(^|\/)connectors\//,
            "$1templates/connectors/"
          );
        } else if (!isTemplate && isInTemplatesDirectory) {
          compatModuleName = compatModuleName.replace(/^templates\//, "");
        }
      }

      output += `import * as Mod${i} from "./${filenameWithoutExtension}";\n`;
      output += `themeCompatModules["${compatModuleName}"] = Mod${i};\n`;

      i += 1;
    }

    output += "export default themeCompatModules;\n";

    return output;
  },
  "virtual:init-settings": (_, { themeId, settings }) => {
    return `
      import { registerSettings } from "discourse/lib/theme-settings-store";
      registerSettings(${themeId}, ${JSON.stringify(settings)});
    `;
  },
  "virtual:theme": (_, { themeId }) => {
    return `
      import { getObjectForTheme } from "discourse/lib/theme-settings-store";

      export const settings = getObjectForTheme(${themeId});

      export function themePrefix(key) {
        return \`theme_translations.${themeId}.\${key}\`;
      }
    `;
  },
};

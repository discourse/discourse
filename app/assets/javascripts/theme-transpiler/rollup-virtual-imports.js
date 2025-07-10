const SUPPORTED_FILE_EXTENSIONS = [".js", ".js.es6", ".hbs", ".gjs"];

export default {
  "virtual:main": (tree, { themeId }) => {
    let output = `
      import "virtual:init-settings";
    `;

    output += "const themeCompatModules = {};\n";

    let i = 1;
    for (const moduleFilename of Object.keys(tree)) {
      let moduleName = moduleFilename.replace(/\.[^\.]+(\.es6)?$/, "");

      if (
        !SUPPORTED_FILE_EXTENSIONS.some((ext) => moduleFilename.endsWith(ext))
      ) {
        // Unsupported file type. Log a warning and skip
        output += `console.warn("[THEME ${themeId}] Unsupported file type: ${moduleFilename}");\n`;
        continue;
      }

      if (moduleFilename.match(/(^|\/)connectors\//)) {
        const isTemplate = moduleFilename.endsWith(".hbs");
        const isInTemplatesDirectory = moduleName.match(/(^|\/)templates\//);

        if (isTemplate && !isInTemplatesDirectory) {
          moduleName = moduleName.replace(
            /(^|\/)connectors\//,
            "$1templates/connectors/"
          );
        } else if (!isTemplate && isInTemplatesDirectory) {
          moduleName = moduleName.replace(/^templates\//, "");
        }
        output += `import * as Mod${i} from "${moduleFilename}";\n`;
        output += `themeCompatModules["${moduleName}"] = Mod${i};\n`;
      } else {
        output += `import * as Mod${i} from "${moduleFilename}";\n`;
        output += `themeCompatModules["${moduleName}"] = Mod${i};\n`;
      }

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

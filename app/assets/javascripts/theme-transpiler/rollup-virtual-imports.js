export default {
  "virtual:main": (tree) => {
    let output = `
      import "virtual:init-settings";
    `;

    output += "const themeCompatModules = {};\n";

    let i = 1;
    for (const moduleFilename of Object.keys(tree)) {
      const moduleName = moduleFilename.replace(/\.[^\.]+(\.es6)?$/, "");

      output += `import * as Mod${i} from "${moduleName}";\n`;
      output += `themeCompatModules["${moduleName}"] = Mod${i};\n`;
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

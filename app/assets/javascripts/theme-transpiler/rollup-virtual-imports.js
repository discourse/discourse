export default {
  "virtual:main": (tree, { themeId, settings }) => {
    const initializers = Object.keys(tree).filter((key) =>
      key.includes("/initializers/")
    );

    let output = `
      import "virtual:init-settings";
    `;

    output += "export const initializers = {};\n";

    let i = 1;
    for (const initializer of initializers) {
      output += `import Init${i} from "${initializer}";\n`;
      output += `initializers["${initializer}"] = Init${i};\n`;
      i += 1;
    }

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

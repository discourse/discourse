const SUPPORTED_FILE_EXTENSIONS = [
  ".js",
  ".js.es6",
  ".hbs",
  ".gjs",
  ".ts",
  ".gts",
];

const IS_CONNECTOR_REGEX = /(^|\/)connectors\//;

export default {
  "virtual:entrypoint": (moduleFilenames, { themeId, pluginName }) => {
    const label = pluginName ? `PLUGIN ${pluginName}` : `THEME ${themeId}`;
    const imports = [];
    const entries = [];
    const warnings = [];

    const exportedModules = new Set();

    let i = 1;
    for (const moduleFilename of moduleFilenames) {
      // Type-only declaration files have no runtime module to export.
      if (moduleFilename.endsWith(".d.ts")) {
        continue;
      }

      if (
        !SUPPORTED_FILE_EXTENSIONS.some((ext) => moduleFilename.endsWith(ext))
      ) {
        // Unsupported file type. Log a warning and skip
        warnings.push(
          `console.warn("[${label}] Unsupported file type: ${moduleFilename}");`
        );
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
          compatModuleName = compatModuleName.replace(
            /(^|\/)templates\//,
            "$1"
          );
        }
      }

      const importPath = filenameWithoutExtension.match(IS_CONNECTOR_REGEX)
        ? moduleFilename
        : filenameWithoutExtension;

      if (exportedModules.has(importPath)) {
        continue;
      }
      exportedModules.add(importPath);

      imports.push(`import * as Mod${i} from "./${importPath}";`);
      entries.push(`  "${compatModuleName}": Mod${i},`);

      i += 1;
    }

    return [
      ...imports,
      ...warnings,
      "const compatModules = {",
      ...entries,
      "};",
      "export default compatModules;",
      "",
    ].join("\n");
  },
  "virtual:theme": ({ themeId }) => {
    return cleanMultiline(`
      import { getObjectForTheme } from "discourse/lib/theme-settings-store";

      export const settings = getObjectForTheme(${themeId});

      export function themePrefix(key) {
        return \`theme_translations.${themeId}.\${key}\`;
      }
    `);
  },
};

// Virtual modules the loader resolves only as a redirect target. They are kept
// out of the default export, and given a null-byte id, so that plugin and theme
// code cannot import them by name.
export const privateVirtualImports = {
  "virtual:attributed-plugin-api": (opts) =>
    attributedEntryFunction({
      module: "discourse/lib/plugin-api",
      exportName: "withPluginApi",
      opts,
    }),
  "virtual:attributed-api-initializer": (opts) =>
    attributedEntryFunction({
      module: "discourse/lib/api",
      exportName: "apiInitializer",
      opts,
    }),
};

// Wraps a core API-entry function so calls from this plugin or theme carry its
// source on `opts`. Plugin and theme imports of `module` resolve here, so the
// wrapper must export everything they are allowed to import from it.
function attributedEntryFunction({ module, exportName, opts }) {
  return cleanMultiline(`
    import { _INTERNAL_SOURCE_KEY } from "discourse/lib/api";
    import { ${exportName} as _${exportName} } from "${module}";

    const SOURCE = Object.freeze(${JSON.stringify(customizationSourceFor(opts))});

    export function ${exportName}(...args) {
      // A leading string is the legacy version argument, which shifts opts along.
      const optsIndex = typeof args[0] === "string" ? 2 : 1;
      args[optsIndex] = { ...args[optsIndex], [_INTERNAL_SOURCE_KEY]: SOURCE };
      return _${exportName}(...args);
    }
  `);
}

function customizationSourceFor({ themeId, pluginName }) {
  return pluginName
    ? { type: "plugin", name: pluginName }
    : { type: "theme", id: themeId };
}

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

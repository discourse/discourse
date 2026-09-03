const SUPPORTED_FILE_EXTENSIONS = [
  ".js",
  ".js.es6",
  ".hbs",
  ".gjs",
  ".ts",
  ".gts",
];

const IS_CONNECTOR_REGEX = /(^|\/)connectors\//;

// Looked up by name at runtime, so these have to stay registered with `define()`.
const EAGER_DIRECTORIES = [
  "connectors",
  "services",
  "models",
  "adapters",
  "discourse-markdown",
];

const EAGER_DIRECTORY_REGEX = new RegExp(
  `^[^/]+/(${EAGER_DIRECTORIES.join("|")})/`
);

function isEagerModule(compatModuleName) {
  return (
    EAGER_DIRECTORY_REGEX.test(compatModuleName) ||
    // Unanchored: `loadInitializers` scans the whole registry.
    /\/(pre-initializers|initializers|api-initializers|instance-initializers)\//.test(
      compatModuleName
    ) ||
    // `mapRoutes` matches on the suffix alone.
    /route-map$/.test(compatModuleName)
  );
}

function stripExtension(filename) {
  return filename.replace(/\.[^\.]+(\.es6)?$/, "");
}

function normalizeModules(moduleFilenames, label) {
  const records = [];
  const warnings = [];
  const seen = new Set();

  for (const moduleFilename of moduleFilenames) {
    if (moduleFilename.endsWith(".d.ts")) {
      continue;
    }

    if (
      !SUPPORTED_FILE_EXTENSIONS.some((ext) => moduleFilename.endsWith(ext))
    ) {
      warnings.push(
        `console.warn("[${label}] Unsupported file type: ${moduleFilename}");`
      );
      continue;
    }

    const filenameWithoutExtension = stripExtension(moduleFilename);

    let compatModuleName = filenameWithoutExtension;

    if (moduleFilename.match(IS_CONNECTOR_REGEX)) {
      const isTemplate = moduleFilename.endsWith(".hbs");
      const isInTemplatesDirectory = moduleFilename.match(/(^|\/)templates\//);

      if (isTemplate && !isInTemplatesDirectory) {
        compatModuleName = compatModuleName.replace(
          IS_CONNECTOR_REGEX,
          "$1templates/connectors/"
        );
      } else if (!isTemplate && isInTemplatesDirectory) {
        compatModuleName = compatModuleName.replace(/(^|\/)templates\//, "$1");
      }
    }

    const importPath = filenameWithoutExtension.match(IS_CONNECTOR_REGEX)
      ? moduleFilename
      : filenameWithoutExtension;

    if (seen.has(importPath)) {
      continue;
    }
    seen.add(importPath);

    records.push({ importPath, compatModuleName });
  }

  return { records, warnings };
}

// Anchored to the top-level segment: a component under `components/chat/routes/` is not a route.
const ROUTE_FILE_REGEX = /^[^/]+\/(routes|controllers|templates)\/(.+)$/;

function routeNameFor(compatModuleName) {
  const match = compatModuleName.match(ROUTE_FILE_REGEX);

  if (!match) {
    return null;
  }

  const [, type, path] = match;

  // Discourse nests connectors and classic component templates under `templates/` too.
  if (
    type === "templates" &&
    (path.startsWith("connectors/") || path.startsWith("components/"))
  ) {
    return null;
  }

  return path.split("/").join(".");
}

// Ember creates these without a `this.route` call, so no route map names them.
const IMPLICIT_ROUTE_SUFFIXES = ["index", "loading", "error"];

function bundleNameFor(routeName, bundleByRoute) {
  let name = routeName;

  while (name) {
    if (bundleByRoute[name]) {
      return bundleByRoute[name];
    }

    const dot = name.lastIndexOf(".");

    if (!IMPLICIT_ROUTE_SUFFIXES.includes(name.slice(dot + 1))) {
      return null;
    }

    name = dot === -1 ? "" : name.slice(0, dot);
  }

  return null;
}

export function routeBundlesFor(records, bundleByRoute) {
  const bundles = new Map();

  if (!bundleByRoute) {
    return [];
  }

  for (const record of records) {
    const routeName = routeNameFor(record.compatModuleName);
    const bundleName = routeName && bundleNameFor(routeName, bundleByRoute);

    if (!bundleName) {
      continue;
    }

    let bundle = bundles.get(bundleName);

    if (!bundle) {
      bundle = { bundleName, names: new Set(), records: [] };
      bundles.set(bundleName, bundle);
    }

    bundle.names.add(routeName);
    bundle.records.push(record);
  }

  return [...bundles.values()].map((bundle) => ({
    ...bundle,
    names: [...bundle.names].sort(),
  }));
}

// The route names a module list contributes, so a caller can tell which entrypoint owns a route.
export function routeNamesFor(moduleFilenames, bundleByRoute) {
  const records = moduleFilenames.map((moduleFilename) => ({
    compatModuleName: stripExtension(moduleFilename),
  }));

  return new Set(
    routeBundlesFor(records, bundleByRoute).flatMap((bundle) => bundle.names)
  );
}

function renderMap(name, records, identifiers) {
  return [
    `const ${name} = {`,
    ...records.map(
      (record) => `  "${record.compatModuleName}": ${identifiers.get(record)},`
    ),
    "};",
  ];
}

export default {
  "virtual:entrypoint": (moduleFilenames, opts, extra) => {
    const { themeId, pluginName, frontendConfig } = opts;
    const label = pluginName ? `PLUGIN ${pluginName}` : `THEME ${themeId}`;

    const { records, warnings } = normalizeModules(moduleFilenames, label);

    // QUnit only finds a test by running the module that registers it, so tests stay eager.
    const isTestEntrypoint = extra?.entrypointName === "test";

    if (isTestEntrypoint || !frontendConfig?.staticModules) {
      const identifiers = new Map(
        records.map((record, i) => [record, `Mod${i + 1}`])
      );

      return [
        ...records.map(
          (record) =>
            `import * as ${identifiers.get(record)} from "./${record.importPath}";`
        ),
        ...warnings,
        ...renderMap("compatModules", records, identifiers),
        "export { compatModules };",
        "export default compatModules;",
        "",
      ].join("\n");
    }

    // `exports` maps the name other bundles import by to the module behind it, which is why the
    // two are kept apart here. A cross-plugin import can spell the module either way.
    const publicNamesByPath = new Map();

    for (const [publicName, internalName] of Object.entries(
      frontendConfig.exports ?? {}
    )) {
      const path = stripExtension(internalName);

      for (const candidate of [path, `${path}/index`]) {
        publicNamesByPath.set(candidate, [
          ...(publicNamesByPath.get(candidate) ?? []),
          publicName,
        ]);
      }
    }

    const bundles = routeBundlesFor(records, opts.routeTables?.bundleByRoute);
    const entrypointName = extra?.entrypointName;

    const eager = records.filter((record) =>
      isEagerModule(record.compatModuleName)
    );
    const shared = records.filter((record) =>
      publicNamesByPath.has(stripExtension(record.importPath))
    );

    // One module can be exported under several names.
    const exported = shared.flatMap((record) =>
      publicNamesByPath
        .get(stripExtension(record.importPath))
        .map((publicName) => ({ publicName, record }))
    );

    const imported = [...new Set([...eager, ...shared])];
    const identifiers = new Map(
      imported.map((record, i) => [record, `Mod${i + 1}`])
    );

    return [
      ...imported.map(
        (record) =>
          `import * as ${identifiers.get(record)} from "./${record.importPath}";`
      ),
      ...warnings,
      ...renderMap("compatModules", eager, identifiers),
      "const pluginExports = {",
      ...exported.map(
        ({ publicName, record }) =>
          `  "${publicName}": ${identifiers.get(record)},`
      ),
      "};",
      "export const routes = [",
      ...bundles.map(
        (bundle) =>
          `  { names: ${JSON.stringify(bundle.names)},` +
          ` load: () => import("virtual:route:${entrypointName}:${bundle.bundleName}") },`
      ),
      "];",
      "export { compatModules };",
      "export default pluginExports;",
      "",
    ].join("\n");
  },
  // The default export goes to `Resolver#addModules`, so it must be a plain module map.
  "virtual:route": (moduleFilenames, opts, bundleName) => {
    const label = opts.pluginName
      ? `PLUGIN ${opts.pluginName}`
      : `THEME ${opts.themeId}`;

    const { records } = normalizeModules(moduleFilenames, label);
    const bundle = routeBundlesFor(
      records,
      opts.routeTables?.bundleByRoute
    ).find((candidate) => candidate.bundleName === bundleName);

    // Null rather than throwing: the caller tries each entrypoint in turn.
    if (!bundle) {
      return null;
    }

    const identifiers = new Map(
      bundle.records.map((record, i) => [record, `Mod${i + 1}`])
    );

    return [
      ...bundle.records.map(
        (record) =>
          `import * as ${identifiers.get(record)} from "./${record.importPath}";`
      ),
      ...renderMap("routeCompatModules", bundle.records, identifiers),
      "export default routeCompatModules;",
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

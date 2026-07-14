const SUPPORTED_FILE_EXTENSIONS = [
  ".js",
  ".js.es6",
  ".hbs",
  ".gjs",
  ".ts",
  ".gts",
];

const IS_CONNECTOR_REGEX = /(^|\/)connectors\//;

// Modules Discourse still looks up by name at runtime, and which therefore have to be
// registered with `define()` even when the rest of the bundle is reached through static
// imports. Everything else — components, helpers, modifiers, lib, unshared models — is
// imported from `.gjs` under `staticModules`, so it can be left to tree-shaking.
const EAGER_MODULE_PATTERNS = [
  // enumerated out of `requirejs.entries` by `loadInitializers`
  /(^|\/)pre-initializers\//,
  /(^|\/)initializers\//,
  /(^|\/)api-initializers\//,
  /(^|\/)instance-initializers\//,
  // scanned out of `requirejs.entries` by `mapRoutes`
  /(^|\/)route-map$/,
  // resolved by name by the plugin outlet system
  /(^|\/)connectors\//,
  // resolved by name via the resolver's suffix trie
  /(^|\/)services\//,
  /(^|\/)models\//,
  /(^|\/)adapters\//,
  /(^|\/)routes\//,
  /(^|\/)controllers\//,
  /(^|\/)templates\//,
];

function isEagerModule(compatModuleName) {
  return EAGER_MODULE_PATTERNS.some((pattern) =>
    pattern.test(compatModuleName)
  );
}

function stripExtension(filename) {
  return filename.replace(/\.[^\.]+(\.es6)?$/, "");
}

// Turns the raw file list into `{ importPath, compatModuleName }` records, dropping type-only
// declarations and warning about file types we cannot compile.
function normalizeModules(moduleFilenames, label) {
  const records = [];
  const warnings = [];
  const seen = new Set();

  for (const moduleFilename of moduleFilenames) {
    // Type-only declaration files have no runtime module to export.
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

// Route names are derived from file paths, the way Embroider does it: strip the
// `routes/` / `controllers/` / `templates/` prefix and join the remaining segments with a dot.
// Ember's resolver convention guarantees the path is the route name.
const ROUTE_FILE_REGEX = /(^|\/)(routes|controllers|templates)\/(.+)$/;

function routeNameFor(compatModuleName) {
  const match = compatModuleName.match(ROUTE_FILE_REGEX);

  if (!match) {
    return null;
  }

  const [, , type, path] = match;

  // Unlike a core app, Discourse nests connectors and classic component templates under
  // `templates/`. They are not routes.
  if (
    type === "templates" &&
    (path.startsWith("connectors/") || path.startsWith("components/"))
  ) {
    return null;
  }

  return path.split("/").join(".");
}

// `splitAtRoutes` values are route-name patterns with at most one trailing star. A star means
// "this route and everything beneath it" — but splitting a route always claims its descendants
// anyway, so `chat.*` and `chat` are the same thing. Reduce both to the base route name.
function splitBasesFor(frontend) {
  return Object.values(frontend?.splitAtRoutes ?? {}).map((pattern) =>
    pattern.replace(/\.?\*$/, "")
  );
}

// The bundle a route belongs to is its nearest splitting ancestor, or itself. Matching the
// longest base gives that directly: `chat.visualizer` beats `chat` for `chat.visualizer`, which
// is what keeps a more specific split out of its parent's bundle.
function splitBaseFor(routeName, splitBases) {
  let match = null;

  for (const base of splitBases) {
    const claims = routeName === base || routeName.startsWith(`${base}.`);

    if (claims && (match === null || base.length > match.length)) {
      match = base;
    }
  }

  return match;
}

// Groups the route files which `splitAtRoutes` claims into one lazy bundle per base route.
// Anything unclaimed is left for the eager set.
export function routeBundlesFor(records, frontend) {
  const splitBases = splitBasesFor(frontend);
  const bundles = new Map();

  if (splitBases.length === 0) {
    return [];
  }

  for (const record of records) {
    const routeName = routeNameFor(record.compatModuleName);

    if (!routeName) {
      continue;
    }

    const base = splitBaseFor(routeName, splitBases);

    if (!base) {
      continue;
    }

    let bundle = bundles.get(base);

    if (!bundle) {
      bundle = { base, names: new Set(), records: [] };
      bundles.set(base, bundle);
    }

    bundle.names.add(routeName);
    bundle.records.push(record);
  }

  return [...bundles.values()].map((bundle) => ({
    ...bundle,
    names: [...bundle.names].sort(),
  }));
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
  "virtual:entrypoint": (moduleFilenames, opts) => {
    const { themeId, pluginName, frontend } = opts;
    const label = pluginName ? `PLUGIN ${pluginName}` : `THEME ${themeId}`;

    const { records, warnings } = normalizeModules(moduleFilenames, label);

    // `compatModules` is what core registers with `define()`; the default export is the
    // cross-bundle lookup table that `babel-resolve-plugin-imports` indexes into. Without
    // `staticModules` they are the same object, and every module is eagerly imported.
    if (!frontend?.staticModules) {
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

    const sharedPaths = new Set(
      (frontend.sharedModules ?? []).map(stripExtension)
    );

    const bundles = routeBundlesFor(records, frontend);
    const split = new Set(bundles.flatMap((bundle) => bundle.records));

    // Route files claimed by a `splitAtRoutes` bundle are loaded lazily, so they must not also
    // be registered eagerly here — that would defeat the split.
    const eager = records.filter(
      (record) => isEagerModule(record.compatModuleName) && !split.has(record)
    );
    const shared = records.filter((record) =>
      sharedPaths.has(stripExtension(record.importPath))
    );

    // A module can be both eager and shared, so import each at most once.
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
      ...renderMap("sharedModules", shared, identifiers),
      "export const routes = [",
      ...bundles.map(
        (bundle) =>
          `  { names: ${JSON.stringify(bundle.names)},` +
          ` load: () => import("virtual:route:${bundle.base}") },`
      ),
      "];",
      "export { compatModules };",
      "export default sharedModules;",
      "",
    ].join("\n");
  },
  // One lazy route bundle. `@embroider/router` awaits this and hands the default export to
  // `Resolver#addModules`, so the shape must be a plain module map.
  "virtual:route": (moduleFilenames, opts, routeName) => {
    const label = opts.pluginName
      ? `PLUGIN ${opts.pluginName}`
      : `THEME ${opts.themeId}`;

    const { records } = normalizeModules(moduleFilenames, label);
    const bundle = routeBundlesFor(records, opts.frontend).find(
      (candidate) => candidate.base === routeName
    );

    if (!bundle) {
      throw new Error(
        `[${label}] No route bundle for "${routeName}" — no route files matched it.`
      );
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

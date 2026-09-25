import { readdirSync, readFileSync } from "node:fs";
import path from "node:path";
import {
  buildRouteTree,
  bundleByRouteFor,
  deriveRoutes,
  parseRouteMap,
  urlTableFor,
} from "../../asset-processor/route-map-parser.js";

const MODULES_ID = "virtual:core-modules";
const ROUTE_PREFIX = "virtual:core-route:";
const RESOLVED_MODULES_ID = `\0${MODULES_ID}`;
const RESOLVED_ROUTE_PREFIX = `\0${ROUTE_PREFIX}`;

const EXTENSIONS = [".gjs", ".js", ".ts", ".gts"];

// Handled by their own entrypoints and dynamic imports.
const SKIPPED_DIRECTORIES = ["static", "workers", "styles"];

// Scanned by name at runtime, at any depth, so these stay registered with `define()`.
const EAGER_DIRECTORIES = [
  "adapters",
  "connectors",
  "initializers",
  "instance-initializers",
  "models",
  "services",
  "templates/components",
  "templates/connectors",
];

// Routes have no bundle of their own unless the map names one.
const DEFAULT_BUNDLE = "other";

const ROUTE_FILE_REGEX = /^(routes|controllers|templates)\/(.+)$/;
const IMPLICIT_ROUTE_SUFFIXES = ["index", "loading", "error"];

function walk(dir, base = dir) {
  const files = [];

  for (const entry of readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    const rel = path.relative(base, full);

    if (entry.name.startsWith(".")) {
      continue;
    }

    if (entry.isDirectory()) {
      if (!SKIPPED_DIRECTORIES.includes(rel)) {
        files.push(...walk(full, base));
      }
    } else if (
      EXTENSIONS.some((ext) => entry.name.endsWith(ext)) &&
      !entry.name.endsWith(".d.ts")
    ) {
      files.push(rel);
    }
  }

  return files.sort();
}

function stripExtension(file) {
  return file.replace(/\.[^./]+$/, "");
}

function routeNameFor(moduleName) {
  const match = moduleName.match(ROUTE_FILE_REGEX);

  if (!match) {
    return null;
  }

  const [, type, rest] = match;

  if (
    type === "templates" &&
    (rest.startsWith("components/") || rest.startsWith("connectors/"))
  ) {
    return null;
  }

  return rest.split("/").join(".");
}

// A route lives in the nearest named ancestor's bundle, matching `BareRouter#lazyRoute`.
function bundleFor(routeName, bundleByRoute) {
  let name = routeName;

  while (name) {
    if (bundleByRoute[name]) {
      return bundleByRoute[name];
    }

    const dot = name.lastIndexOf(".");
    name = dot === -1 ? "" : name.slice(0, dot);
  }

  return null;
}

function isEager(moduleName) {
  return (
    EAGER_DIRECTORIES.some((dir) => moduleName.startsWith(`${dir}/`)) ||
    /route-map$/.test(moduleName)
  );
}

function renderModuleMap(name, records, appDir) {
  const lines = records.map(
    (record, i) =>
      `import * as Mod${i} from ${JSON.stringify(path.join(appDir, record.file))};`
  );

  return [
    ...lines,
    `const ${name} = {`,
    ...records.map(
      (record, i) =>
        `  ${JSON.stringify(`discourse/${record.moduleName}`)}: Mod${i},`
    ),
    "};",
  ];
}

export default function discourseCoreModules({ appDir, routeMap, tables }) {
  appDir = path.resolve(appDir);
  let plan;

  function buildPlan(parse) {
    const source = readFileSync(path.join(appDir, routeMap), "utf8");
    const parsed = parseRouteMap(parse(source), {
      filename: routeMap,
      source,
      label: "CORE",
      lenient: true,
    });
    const { root } = buildRouteTree([{ ...parsed, core: true }]);
    const derived = deriveRoutes(root, { coreDefaultBundle: DEFAULT_BUNDLE });
    const bundleByRoute = bundleByRouteFor(derived);

    const eager = [];
    const bundles = new Map();

    for (const file of walk(appDir)) {
      const moduleName = stripExtension(file);
      const record = { file, moduleName };

      if (isEager(moduleName)) {
        eager.push(record);
        continue;
      }

      const routeName = routeNameFor(moduleName);

      if (!routeName) {
        continue;
      }

      const bundleName = bundleFor(routeName, bundleByRoute);

      if (!bundleName) {
        eager.push(record);
        continue;
      }

      let bundle = bundles.get(bundleName);

      if (!bundle) {
        bundle = { bundleName, names: new Set(), records: [] };
        bundles.set(bundleName, bundle);
      }

      bundle.records.push(record);
    }

    for (const route of derived) {
      bundles.get(route.bundleName)?.names.add(route.name);
    }

    plan = {
      eager,
      bundles: [...bundles.values()].map((bundle) => ({
        ...bundle,
        names: [...bundle.names].sort(),
      })),
      urlTable: urlTableFor(derived),
    };

    Object.assign(tables, plan);
    return plan;
  }

  return {
    name: "discourse-core-modules",

    buildStart() {
      buildPlan((source) => this.parse(source));
    },

    resolveId: {
      filter: { id: [/^virtual:core-modules$/, /^virtual:core-route:/] },
      handler(source) {
        return `\0${source}`;
      },
    },

    load: {
      filter: { id: [/^\0virtual:core-modules$/, /^\0virtual:core-route:/] },
      handler(id) {
        if (id === RESOLVED_MODULES_ID) {
          return [
            ...renderModuleMap("compatModules", plan.eager, appDir),
            "export const routes = [",
            ...plan.bundles.map(
              (bundle) =>
                `  { names: ${JSON.stringify(bundle.names)},` +
                ` load: () => import(${JSON.stringify(`${ROUTE_PREFIX}${bundle.bundleName}`)}) },`
            ),
            "];",
            "export default compatModules;",
            "",
          ].join("\n");
        }

        const bundleName = id.slice(RESOLVED_ROUTE_PREFIX.length);
        const bundle = plan.bundles.find((b) => b.bundleName === bundleName);

        if (!bundle) {
          this.error(`No core route bundle named "${bundleName}"`);
        }

        return [
          ...renderModuleMap("routeModules", bundle.records, appDir),
          "export default routeModules;",
          "",
        ].join("\n");
      },
    },
  };
}

// Route bundles by url glob, most specific first, for the html to preload.
export function routeBundlesFor(bundle, tables) {
  const fileByBundle = {};

  for (const [fileName, chunk] of Object.entries(bundle)) {
    if (
      chunk.type === "chunk" &&
      chunk.facadeModuleId?.startsWith(RESOLVED_ROUTE_PREFIX)
    ) {
      fileByBundle[chunk.facadeModuleId.slice(RESOLVED_ROUTE_PREFIX.length)] =
        fileName;
    }
  }

  return (tables.urlTable ?? [])
    .filter(({ bundleName }) => fileByBundle[bundleName])
    .map(({ bundleName, url }) => ({
      bundleName,
      url,
      fileName: fileByBundle[bundleName],
    }));
}

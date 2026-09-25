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

// Looked up by name from a route's code, so they travel with that route.
const EXTRA_ROUTE_BUNDLES = { nested: "topic", "user-topics-list": "other" };

// Loaded alongside a bundle, for code that its routes use synchronously.
const BUNDLE_PRELOADS = {
  topic: ["discourse/data/warp-store-impl"],
  other: ["discourse/data/warp-store-impl"],
};

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

// Filled in at the end of the build, once the module graph is complete.
const chunkGroups = { boot: new Set(), shared: new Set(), byBundle: new Map() };

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
    const bundleByRoute = {
      ...EXTRA_ROUTE_BUNDLES,
      ...bundleByRouteFor(derived),
    };

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
      preloads: BUNDLE_PRELOADS,
      appDir,
    };

    Object.assign(tables, plan);
    return plan;
  }

  return {
    name: "discourse-core-modules",

    buildStart() {
      buildPlan((source) => this.parse(source));
    },

    // Everything the entrypoint reaches statically is one chunk, and each route
    // bundle's own closure is one chunk. Modules shared by several route bundles
    // go in a chunk of their own, so no route page loads another route's code.
    buildEnd() {
      const closure = (start) => {
        const seen = new Set();
        const stack = [start];
        while (stack.length) {
          const id = stack.pop();
          if (seen.has(id)) {
            continue;
          }
          seen.add(id);
          const info = this.getModuleInfo(id);
          for (const dep of info?.importedIds ?? []) {
            stack.push(dep);
          }
        }
        return seen;
      };

      const entry = [...this.getModuleIds()].find(
        (id) => this.getModuleInfo(id)?.isEntry && id.endsWith("/discourse.js")
      );
      chunkGroups.boot = closure(entry);

      const count = new Map();
      chunkGroups.byBundle = new Map();
      for (const bundle of plan.bundles) {
        const ids = [`${RESOLVED_ROUTE_PREFIX}${bundle.bundleName}`];
        const own = new Set();
        for (const id of ids.flatMap((start) => [...closure(start)])) {
          if (!chunkGroups.boot.has(id)) {
            own.add(id);
            count.set(id, (count.get(id) ?? 0) + 1);
          }
        }
        chunkGroups.byBundle.set(bundle.bundleName, own);
      }
      chunkGroups.shared = new Set(
        [...count].filter(([, n]) => n > 1).map(([id]) => id)
      );
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
            ...plan.bundles.map((bundle) => {
              const imports = [
                `${ROUTE_PREFIX}${bundle.bundleName}`,
                ...(BUNDLE_PRELOADS[bundle.bundleName] ?? []),
              ].map((specifier) => `import(${JSON.stringify(specifier)})`);

              return (
                `  { names: ${JSON.stringify(bundle.names)},` +
                ` load: () => Promise.all([${imports.join(", ")}]).then(([m]) => m) },`
              );
            }),
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
  const fileBySpecifier = {};

  const specifierFor = (id) => {
    if (id.startsWith(RESOLVED_ROUTE_PREFIX)) {
      return { bundleName: id.slice(RESOLVED_ROUTE_PREFIX.length) };
    }
    if (id.startsWith(`${tables.appDir}/`)) {
      return {
        specifier: `discourse/${stripExtension(
          path.relative(tables.appDir, id)
        )}`,
      };
    }
    return {};
  };

  const record = ({ bundleName, specifier }, fileName, table) => {
    if (bundleName && !(bundleName in table.bundles)) {
      table.bundles[bundleName] = fileName;
    }
    if (specifier && !(specifier in table.specifiers)) {
      table.specifiers[specifier] = fileName;
    }
  };

  // A facade chunk is what an import resolves to, so it wins over the chunk
  // that merely contains the module.
  const facades = { bundles: {}, specifiers: {} };
  const containers = { bundles: {}, specifiers: {} };

  for (const [fileName, chunk] of Object.entries(bundle)) {
    if (chunk.type !== "chunk") {
      continue;
    }
    if (chunk.facadeModuleId) {
      record(specifierFor(chunk.facadeModuleId), fileName, facades);
    }
    for (const id of Object.keys(chunk.modules)) {
      record(specifierFor(id), fileName, containers);
    }
  }

  Object.assign(fileByBundle, containers.bundles, facades.bundles);
  Object.assign(fileBySpecifier, containers.specifiers, facades.specifiers);

  return (tables.urlTable ?? [])
    .filter(({ bundleName }) => fileByBundle[bundleName])
    .map(({ bundleName, url }) => ({
      bundleName,
      url,
      fileName: fileByBundle[bundleName],
      preloads: (tables.preloads?.[bundleName] ?? [])
        .map((specifier) => fileBySpecifier[specifier])
        .filter(Boolean),
    }));
}

export function coreChunkGroups(bundleNames) {
  return [
    {
      name: "discourse-boot",
      priority: 30,
      test: (id) => chunkGroups.boot.has(id),
    },
    {
      name: "route-shared",
      priority: 20,
      test: (id) => chunkGroups.shared.has(id),
    },
    ...bundleNames.map((bundleName) => ({
      name: `route-${bundleName}`,
      priority: 10,
      test: (id) => chunkGroups.byBundle.get(bundleName)?.has(id) ?? false,
    })),
  ];
}

import { createHash } from "node:crypto";
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
  "templates/components",
  "templates/connectors",
];

// Routes have no bundle of their own unless the map names one.
const DEFAULT_BUNDLE = "other";

// Looked up by name from a route's code, so they travel with that route.
const EXTRA_ROUTE_BUNDLES = {
  nested: "topic",
  "user-topics-list": "other",
  composer: "other",
  "build-category-route": "discovery",
  "build-topic-route": "discovery",
  "build-private-messages-route": "other",
  "build-private-messages-group-route": "other",
  "build-group-messages-route": "other",
  "restricted-user": "other",
  "user-activity-stream": "other",
  "user-topic-list": "other",
};

// Models that only these route bundles create. A model in several bundles is
// registered by each; an empty list means it is only ever imported.
const MODEL_BUNDLES = {
  composer: [],
  posts: ["other"],
  post: ["topic"],
  "post-stream": ["topic"],
  "topic-details": ["topic"],
  "topic-timer": ["topic"],
  "post-localization": ["topic"],
  "topic-localization": ["topic"],
  "action-summary": ["topic"],
  bookmark: ["topic", "other"],
  group: ["topic", "other"],
  "group-history": ["other"],
  "associated-group": ["other"],
  reviewable: ["other"],
  "reviewable-history": ["other"],
  "user-action": ["other"],
  "user-action-group": ["other"],
  "user-action-stat": ["other"],
  "user-stream": ["other"],
  "user-posts-stream": ["other"],
  "user-drafts-stream": ["other"],
  "user-draft": ["other"],
  "user-badge": ["other"],
  badge: ["other"],
  "badge-grouping": ["other"],
  "badge-type": ["other"],
  invite: ["other"],
  "login-method": ["other"],
  "pending-post": ["other"],
  "static-page": ["other"],
  "published-page": ["other"],
  "tag-group": ["other"],
  "tag-info": ["other"],
  "tag-notification": ["other"],
  "tag-settings": ["other"],
  "live-post-counts": ["other"],
};

// Routes the map builds in loops from site data, which the parser cannot see.
const EXTRA_ROUTE_URLS = {
  discovery: [
    "latest",
    "top",
    "new",
    "unread",
    "unseen",
    "hot",
    "read",
    "posted",
    "bookmarks",
  ],
};

// Loaded alongside a bundle, for code that its routes use synchronously.
const BUNDLE_PRELOADS = {
  topic: ["discourse/data/warp-store-impl"],
  other: ["discourse/data/warp-store-impl"],
};

const ROUTE_FILE_REGEX = /^(routes|controllers|templates)\/(.+)$/;

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
const chunkGroups = { nameById: new Map() };

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

      const modelBundles = moduleName.startsWith("models/")
        ? MODEL_BUNDLES[moduleName.slice("models/".length)]
        : null;

      if (modelBundles) {
        for (const bundleName of modelBundles) {
          let bundle = bundles.get(bundleName);

          if (!bundle) {
            bundle = { bundleName, names: new Set(), records: [] };
            bundles.set(bundleName, bundle);
          }

          bundle.records.push(record);
        }
        continue;
      }

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
      urlTable: urlTableFor([
        ...derived,
        ...Object.entries(EXTRA_ROUTE_URLS).flatMap(([bundleName, urls]) =>
          urls.map((url) => ({ name: `${bundleName}.${url}`, url, bundleName }))
        ),
      ]),
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

    // Everything the entrypoint reaches statically is one chunk. Beyond that,
    // each route bundle and each dynamically imported module owns the modules
    // only it reaches; modules reached by several owners share one chunk, so
    // no page loads another route's code.
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
          for (const dep of this.getModuleInfo(id)?.importedIds ?? []) {
            stack.push(dep);
          }
        }
        return seen;
      };

      const ids = [...this.getModuleIds()];
      const entry = ids.find(
        (id) => this.getModuleInfo(id)?.isEntry && id.endsWith("/discourse.js")
      );
      const boot = closure(entry);

      const owners = new Map();
      const claim = (owner, start) => {
        for (const id of closure(start)) {
          if (!boot.has(id)) {
            (owners.get(id) ?? owners.set(id, new Set()).get(id)).add(owner);
          }
        }
      };

      for (const bundle of plan.bundles) {
        claim(
          `route-${bundle.bundleName}`,
          `${RESOLVED_ROUTE_PREFIX}${bundle.bundleName}`
        );
      }

      for (const id of ids) {
        if (
          !boot.has(id) &&
          !id.startsWith(RESOLVED_ROUTE_PREFIX) &&
          this.getModuleInfo(id)?.dynamicImporters.length
        ) {
          claim(`on-demand-${path.basename(id).replace(/\.[^.]+$/, "")}`, id);
        }
      }

      chunkGroups.nameById = new Map();
      for (const id of boot) {
        chunkGroups.nameById.set(id, "discourse-boot");
      }
      for (const [id, set] of owners) {
        const routes = [...set].filter((owner) => owner.startsWith("route-"));
        let name;

        if (routes.length > 1) {
          name = "route-shared";
        } else if (set.size === 1) {
          name = [...set][0];
        } else {
          // One chunk per combination of owners, so a page loads only what it
          // reaches and an on-demand import never drags a whole route along.
          name = `shared-${createHash("md5")
            .update([...set].sort().join("+"))
            .digest("hex")
            .slice(0, 8)}`;
        }

        chunkGroups.nameById.set(id, name);
      }
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
            'import { getOwnerWithFallback } from "discourse/lib/get-owner";',
            'import { scopeFor } from "discourse/lib/service";',
            "// A bundle's `-setup` module registers what its routes build at runtime.",
            "function ready(bundleName, module) {",
            "  const setup = module.default[`discourse/routes/${bundleName}/-setup`];",
            "  setup?.default(scopeFor(getOwnerWithFallback()));",
            "  return module;",
            "}",
            ...renderModuleMap("compatModules", plan.eager, appDir),
            "export const routes = [",
            ...plan.bundles.map((bundle) => {
              const imports = [
                `${ROUTE_PREFIX}${bundle.bundleName}`,
                ...(BUNDLE_PRELOADS[bundle.bundleName] ?? []),
              ].map((specifier) => `import(${JSON.stringify(specifier)})`);

              return (
                `  { names: ${JSON.stringify(bundle.names)},` +
                ` load: () => Promise.all([${imports.join(", ")}]).then(([m]) => ready(${JSON.stringify(bundle.bundleName)}, m)) },`
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

export function coreChunkGroups() {
  return [{ name: (id) => chunkGroups.nameById.get(id) ?? null }];
}

import { readFileSync } from "fs";
import { isAbsolute, join, relative } from "path";
import { RESOLVED_PREFIX as URL_IMPORT_PREFIX } from "./dynamic-chunk-url-plugin.mjs";

const NODE_MODULES = "/node_modules/";
const EXAMPLES_PER_EDGE = 3;

/**
 * Writes `manifest/bundle-graph.json`: every chunk's modules, its static,
 * dynamic and URL imports, example module-level imports behind each
 * cross-chunk edge, and every module's static importers. The
 * importers explain code that moved into another chunk, such as lazy code
 * now imported statically, where no cross-chunk import is left to show it.
 * CI compares this file between builds to report new bundles, growth and
 * new connections, taking sizes from the bundle analyzer report.
 *
 * @param {{ root: string }} options `root` makes module ids relative.
 */
export default function bundleGraphPlugin({ root }) {
  const versions = new Map();
  const versionOf = (packageDir) => {
    if (!versions.has(packageDir)) {
      versions.set(packageDir, readPackageVersion(packageDir));
    }
    return versions.get(packageDir);
  };
  const normalize = (id) => normalizeModuleId(id, root, versionOf);

  return {
    name: "bundle-graph",

    generateBundle(_outputOptions, bundle) {
      const chunkOfModule = new Map();
      const chunks = {};
      const assets = {};
      const entries = {};
      const importers = new Map();

      for (const [fileName, output] of Object.entries(bundle)) {
        if (output.type !== "chunk") {
          if (!/\.(map|br)$/.test(fileName)) {
            assets[fileName] = { label: labelOf(fileName) };
          }
          continue;
        }
        for (const moduleId of output.moduleIds) {
          chunkOfModule.set(moduleId, fileName);
        }
        if (output.isEntry) {
          entries[output.name] = fileName;
        }
      }

      for (const [fileName, chunk] of Object.entries(bundle)) {
        if (chunk.type !== "chunk") {
          continue;
        }

        const examples = {};
        const addExample = (kind, from, to) => {
          const targetFile = chunkOfModule.get(to);
          if (!targetFile || targetFile === fileName) {
            return;
          }
          const list = (examples[`${kind}:${targetFile}`] ??= []);
          if (list.length < EXAMPLES_PER_EDGE) {
            list.push({ from: normalize(from), to: normalize(to) });
          }
        };

        for (const moduleId of chunk.moduleIds) {
          const info = !moduleId.startsWith(URL_IMPORT_PREFIX)
            ? this.getModuleInfo(moduleId)
            : null;
          if (!info) {
            continue;
          }

          for (const imported of info.importedIds) {
            if (imported.startsWith(URL_IMPORT_PREFIX)) {
              addExample(
                "url",
                moduleId,
                imported.slice(URL_IMPORT_PREFIX.length)
              );
            } else {
              addExample("static", moduleId, imported);
            }
          }
          for (const imported of info.dynamicallyImportedIds) {
            addExample("dynamic", moduleId, imported);
          }

          importers.set(normalize(moduleId), info.importers.map(normalize));
        }

        chunks[fileName] = {
          label: labelOf(fileName),
          kind: chunk.isEntry
            ? "entry"
            : chunk.isDynamicEntry
              ? "lazy"
              : "shared",
          facade: chunk.facadeModuleId ? normalize(chunk.facadeModuleId) : null,
          imports: [...chunk.imports].sort(),
          dynamicImports: chunk.dynamicImports
            .filter((file) => file !== fileName)
            .sort(),
          urlImports: Object.keys(examples)
            .filter((key) => key.startsWith("url:"))
            .map((key) => key.slice("url:".length))
            .sort(),
          modules: chunk.moduleIds.map(normalize).sort(),
          examples,
        };
      }

      this.emitFile({
        type: "asset",
        fileName: "manifest/bundle-graph.json",
        source: stableStringify({
          version: 3,
          entries,
          chunks,
          assets,
          ...indexedImporters(importers),
        }),
      });
    },
  };
}

/**
 * The filename part before the content hash, e.g. `admin` for
 * `assets/js/admin-gwfrhsfc.digested.js`. Files without a digested hash
 * keep their whole name. Follows the output file name patterns in the build
 * config.
 */
export function labelOf(fileName) {
  const base = fileName.split("/").pop();
  return base.replace(/-[a-z0-9]+\.digested\.[a-z0-9]+$/, "");
}

/**
 * Makes a module id stable across machines: relative to `root`, and
 * `<package>@<version>/<path>` for node_modules, whatever the package
 * manager's directory layout.
 */
export function normalizeModuleId(id, root, versionOf = () => undefined) {
  let prefix = "";
  let path = id;
  if (path.startsWith("\0")) {
    path = path.slice(1);
    prefix = path.startsWith("virtual:") ? "" : "virtual:";
  }

  // Virtual ids like `virtual:some-plugin:/abs/path.js` embed a path.
  const scheme = path.match(/^((?:[\w-]+:)+)(\/.*)$/);
  if (scheme) {
    return `${prefix}${scheme[1]}${normalizeModuleId(scheme[2], root, versionOf)}`;
  }

  const [file, query] = splitQuery(path);
  const posixFile = file.replaceAll("\\", "/");
  const packageStart = posixFile.lastIndexOf(NODE_MODULES);

  if (packageStart !== -1) {
    const inPackages = posixFile.slice(packageStart + NODE_MODULES.length);
    const nameParts = inPackages.startsWith("@") ? 2 : 1;
    const segments = inPackages.split("/");
    const packageName = segments.slice(0, nameParts).join("/");
    const rest = segments.slice(nameParts).join("/");
    const version = versionOf(
      posixFile.slice(0, packageStart + NODE_MODULES.length) + packageName
    );
    return `${prefix}${packageName}${version ? `@${version}` : ""}/${rest}${query}`;
  }

  if (isAbsolute(file)) {
    return `${prefix}${relative(root, file).replaceAll("\\", "/")}${query}`;
  }
  return `${prefix}${posixFile}${query}`;
}

function splitQuery(path) {
  const index = path.indexOf("?");
  return index === -1 ? [path, ""] : [path.slice(0, index), path.slice(index)];
}

function readPackageVersion(packageDir) {
  try {
    return JSON.parse(readFileSync(join(packageDir, "package.json"), "utf8"))
      .version;
  } catch {
    return undefined;
  }
}

/**
 * `moduleIds` sorted, and `importers[i]` as indices into it: the importer
 * graph has tens of thousands of edges, which as strings would triple the
 * file.
 */
function indexedImporters(importers) {
  const moduleIds = [...importers.keys()].sort();
  const indexOf = new Map(moduleIds.map((id, i) => [id, i]));
  return {
    moduleIds,
    importers: moduleIds.map((id) =>
      [...new Set(importers.get(id).map((importer) => indexOf.get(importer)))]
        .filter((i) => i !== undefined)
        .sort((a, b) => a - b)
    ),
  };
}

/** JSON with object keys sorted, so the file is reproducible. */
export function stableStringify(value) {
  return JSON.stringify(sortKeys(value), null, 1);
}

function sortKeys(value) {
  if (Array.isArray(value)) {
    return value.map(sortKeys);
  }
  if (value && typeof value === "object") {
    return Object.fromEntries(
      Object.keys(value)
        .sort()
        .map((key) => [key, sortKeys(value[key])])
    );
  }
  return value;
}

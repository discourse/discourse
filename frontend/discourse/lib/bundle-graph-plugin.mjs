import { readFileSync } from "fs";
import { dirname, isAbsolute, join, relative, resolve } from "path";
import { RESOLVED_PREFIX as URL_IMPORT_PREFIX } from "./dynamic-chunk-url-plugin.mjs";

const NODE_MODULES = "/node_modules/";
const EXAMPLES_PER_EDGE = 3;
const UNMAPPED = "(unmapped)";

const BASE64_VALUES = new Int8Array(128).fill(-1);
[..."ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"].forEach(
  (char, i) => (BASE64_VALUES[char.charCodeAt(0)] = i)
);
const COMMA = ",".charCodeAt(0);
const SEMICOLON = ";".charCodeAt(0);

/**
 * Writes `manifest/bundle-graph.json`: every chunk's modules (with minified
 * bytes), its static, dynamic and URL imports, example module-level imports
 * behind each cross-chunk edge, and every module's static importers. The
 * importers explain code that moved into another chunk, such as lazy code
 * now imported statically, where no cross-chunk import is left to show it.
 * CI compares this file between builds to report new bundles, growth and
 * new connections.
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

    generateBundle(outputOptions, bundle) {
      const outDir = outputOptions.dir ?? root;
      const chunkOfModule = new Map();
      const chunks = {};
      const assets = {};
      const entries = {};
      const importers = new Map();

      for (const [fileName, output] of Object.entries(bundle)) {
        if (output.type !== "chunk") {
          if (!fileName.endsWith(".map")) {
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
          modules: moduleBytes(chunk, fileName, outDir, normalize),
          examples,
        };
      }

      this.emitFile({
        type: "asset",
        fileName: "manifest/bundle-graph.json",
        source: stableStringify({
          version: 2,
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
 * Minified bytes per module, counted from the chunk's source map: every
 * generated column up to the next mapping belongs to the mapped source.
 * One pass over the mappings, as the entry chunk has over a million.
 */
function moduleBytes(chunk, fileName, outDir, normalize) {
  const bytes = {};
  for (const moduleId of chunk.moduleIds) {
    bytes[normalize(moduleId)] = 0;
  }

  const map = chunk.map;
  if (!map?.mappings) {
    bytes[UNMAPPED] = chunk.code.length;
    return bytes;
  }

  const code = chunk.code;
  const unmapped = map.sources.length;
  const totals = new Float64Array(unmapped + 1);
  const lineEnds = [];
  for (
    let at = code.indexOf("\n");
    at !== -1;
    at = code.indexOf("\n", at + 1)
  ) {
    lineEnds.push(at + 1);
  }
  lineEnds.push(code.length);

  const mappings = map.mappings;
  const fields = [0, 0, 0, 0, 0];
  let line = 0;
  let lineStart = 0;
  let lineEnd = lineEnds[0];
  let charged = 0;
  let current = unmapped;
  let column = 0;
  let sourceIndex = 0;
  let index = 0;

  while (index < mappings.length) {
    const char = mappings.charCodeAt(index);
    if (char === SEMICOLON) {
      totals[current] += lineEnd - charged;
      line++;
      lineStart = lineEnd;
      lineEnd = lineEnds[line] ?? code.length;
      charged = lineStart;
      current = unmapped;
      column = 0;
      index++;
      continue;
    }
    if (char === COMMA) {
      index++;
      continue;
    }

    let count = 0;
    while (
      index < mappings.length &&
      mappings.charCodeAt(index) !== COMMA &&
      mappings.charCodeAt(index) !== SEMICOLON
    ) {
      // Base64 VLQ, as defined by the source map spec.
      /* eslint-disable no-bitwise */
      let value = 0;
      let shift = 0;
      let digit;
      do {
        digit = BASE64_VALUES[mappings.charCodeAt(index++)];
        value += (digit & 31) << shift;
        shift += 5;
      } while (digit & 32);
      fields[count++] = value & 1 ? -(value >>> 1) : value >>> 1;
      /* eslint-enable no-bitwise */
    }

    column += fields[0];
    const offset = Math.min(lineStart + column, lineEnd);
    totals[current] += Math.max(0, offset - charged);
    charged = Math.max(charged, offset);
    if (count >= 4) {
      sourceIndex += fields[1];
      current = sourceIndex;
    } else {
      current = unmapped;
    }
  }

  totals[current] += lineEnd - charged;
  for (let rest = line + 1; rest < lineEnds.length; rest++) {
    totals[unmapped] += lineEnds[rest] - lineEnds[rest - 1];
  }

  const mapDir = resolve(outDir, dirname(fileName), map.sourceRoot ?? "");
  let orphaned = 0;
  map.sources.forEach((source, i) => {
    const key = source ? normalize(resolve(mapDir, source)) : UNMAPPED;
    if (totals[i] > 0 && Object.hasOwn(bytes, key)) {
      bytes[key] += totals[i];
    } else {
      orphaned += totals[i];
    }
  });
  bytes[UNMAPPED] = totals[unmapped];
  shareOrphanedBytes(bytes, chunk, normalize, orphaned);
  if (bytes[UNMAPPED] === 0) {
    delete bytes[UNMAPPED];
  }
  return bytes;
}

/**
 * A dependency that ships its own source map leaves sources in the chunk map
 * that are not module ids (its original `../src/*.ts` files), and its module
 * gets no mapped bytes. Those bytes go to the chunk's modules that got none,
 * in proportion to their rendered length.
 */
function shareOrphanedBytes(bytes, chunk, normalize, orphaned) {
  if (orphaned === 0) {
    return;
  }
  const receivers = chunk.moduleIds
    .map((id) => [normalize(id), chunk.modules[id]?.renderedLength ?? 0])
    .filter(([key, length]) => bytes[key] === 0 && length > 0);
  const totalLength = receivers.reduce((sum, [, length]) => sum + length, 0);
  if (totalLength === 0) {
    bytes[UNMAPPED] += orphaned;
    return;
  }
  let given = 0;
  for (const [key, length] of receivers) {
    const share = Math.floor((orphaned * length) / totalLength);
    bytes[key] += share;
    given += share;
  }
  bytes[receivers[0][0]] += orphaned - given;
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

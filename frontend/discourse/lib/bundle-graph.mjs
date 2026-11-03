import { RESOLVED_PREFIX as URL_IMPORT_PREFIX } from "./dynamic-chunk-url-plugin.mjs";

// Build metadata, source maps and precompressed copies are not assets a page
// loads.
const NOT_LOADED = /^manifest\/|\.(map|br)$/;

/**
 * How the chunks of a finished bundle connect: each chunk's dynamic and URL
 * imports with an example module-level import behind each cross-chunk edge,
 * the other files it emits, and every module's static importers. The
 * importers explain code that moved into another chunk, such as lazy code
 * now imported statically, where no cross-chunk import is left to show it.
 *
 * @param {object} bundle The output bundle.
 * @param {(id: string) => object | null} getModuleInfo
 * @param {(id: string) => string} normalize Makes a module id stable.
 */
export function bundleGraph(bundle, getModuleInfo, normalize) {
  const chunkOfModule = new Map();
  const assets = [];
  for (const [fileName, output] of Object.entries(bundle)) {
    if (output.type === "chunk") {
      for (const moduleId of output.moduleIds) {
        chunkOfModule.set(moduleId, fileName);
      }
    } else if (!NOT_LOADED.test(fileName)) {
      assets.push(fileName);
    }
  }

  const chunks = {};
  const importers = new Map();
  for (const [fileName, chunk] of Object.entries(bundle)) {
    if (chunk.type !== "chunk") {
      continue;
    }

    const examples = {};
    const addExample = (kind, from, to) => {
      const targetFile = chunkOfModule.get(to);
      if (targetFile && targetFile !== fileName) {
        examples[`${kind}:${targetFile}`] ??= {
          from: normalize(from),
          to: normalize(to),
        };
      }
    };

    for (const moduleId of chunk.moduleIds) {
      const info = !moduleId.startsWith(URL_IMPORT_PREFIX)
        ? getModuleInfo(moduleId)
        : null;
      if (!info) {
        continue;
      }

      for (const imported of info.importedIds) {
        if (imported.startsWith(URL_IMPORT_PREFIX)) {
          addExample("url", moduleId, imported.slice(URL_IMPORT_PREFIX.length));
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
      dynamicImports: chunk.dynamicImports.filter((file) => file !== fileName),
      urlImports: Object.keys(examples)
        .filter((key) => key.startsWith("url:"))
        .map((key) => key.slice("url:".length)),
      examples,
    };
  }

  return { chunks, assets, ...indexedImporters(importers) };
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

import { RESOLVED_PREFIX as URL_IMPORT_PREFIX } from "./dynamic-chunk-url-plugin.mjs";

/**
 * How the chunks of a finished bundle connect. Per chunk: the modules that
 * dynamically import it and which of its modules they import, its own dynamic
 * imports, and an example module-level import behind each static, dynamic or
 * URL import of another chunk. Also the assets modules bring in, with their
 * sizes, and every module's static importers. The importers explain code
 * that moved into another chunk, such as lazy code now imported statically,
 * where no cross-chunk import is left to show it. Sorted, like the report.
 *
 * @param {object} bundle The output bundle.
 * @param {(id: string) => object | null} getModuleInfo
 * @param {(id: string) => string} normalize Makes a module id stable.
 */
export function bundleGraph(bundle, getModuleInfo, normalize) {
  const chunkOfModule = new Map();
  const assets = {};
  for (const [fileName, output] of Object.entries(bundle)) {
    if (output.type === "chunk") {
      for (const moduleId of output.moduleIds) {
        chunkOfModule.set(moduleId, fileName);
      }
    } else if (output.originalFileNames.length) {
      // Source maps, precompressed copies and build metadata come from no
      // module.
      assets[fileName] = Buffer.byteLength(output.source);
    }
  }

  const chunks = {};
  const importers = new Map();
  for (const [fileName, chunk] of Object.entries(bundle)) {
    if (chunk.type !== "chunk") {
      continue;
    }

    // Per module rather than of the facade, so a chunk that several dynamic
    // entries were merged into still names what pulls it in.
    const importSites = new Set();
    // A chunk without a facade has no other name for what loads it lazily.
    const dynamicEntryModules = new Set();
    const examples = { static: {}, dynamic: {}, url: {} };
    const addExample = (kind, from, to) => {
      const targetFile = chunkOfModule.get(to);
      if (targetFile && targetFile !== fileName) {
        const example = { from: normalize(from), to: normalize(to) };
        const kept = examples[kind][targetFile];
        if (
          !kept ||
          `${example.from}\0${example.to}` < `${kept.from}\0${kept.to}`
        ) {
          examples[kind][targetFile] = example;
        }
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
      for (const importer of info.dynamicImporters) {
        importSites.add(normalize(importer));
        const importerFile = chunkOfModule.get(importer);
        if (importerFile && importerFile !== fileName) {
          dynamicEntryModules.add(normalize(moduleId));
        }
      }

      importers.set(normalize(moduleId), info.importers.map(normalize));
    }

    chunks[fileName] = {
      importSites: [...importSites].sort(),
      dynamicEntryModules: [...dynamicEntryModules].sort(),
      dynamicImports: chunk.dynamicImports
        .filter((file) => file !== fileName)
        .sort(),
      examples: {
        static: sortedByKey(examples.static),
        dynamic: sortedByKey(examples.dynamic),
        url: sortedByKey(examples.url),
      },
    };
  }

  return {
    chunks,
    assets: sortedByKey(assets),
    ...indexedImporters(importers),
  };
}

function sortedByKey(object) {
  return Object.fromEntries(
    Object.keys(object)
      .sort()
      .map((key) => [key, object[key]])
  );
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

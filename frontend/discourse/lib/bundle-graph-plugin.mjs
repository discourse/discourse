import { moduleIdNormalizer } from "./bundle-module-ids.mjs";
import { RESOLVED_PREFIX as URL_IMPORT_PREFIX } from "./dynamic-chunk-url-plugin.mjs";

/**
 * Writes `manifest/bundle-graph.json`: every chunk's static, dynamic and URL
 * imports, an example module-level import behind each cross-chunk edge, and
 * every module's static importers. The
 * importers explain code that moved into another chunk, such as lazy code
 * now imported statically, where no cross-chunk import is left to show it.
 * CI compares this file between builds to report new bundles, growth and
 * new connections, taking modules and sizes from the bundle analyzer report,
 * whose module ids match these.
 *
 * @param {{ root: string }} options `root` makes module ids relative.
 */
export default function bundleGraphPlugin({ root }) {
  const normalize = moduleIdNormalizer(root);

  return {
    name: "bundle-graph",

    generateBundle(_outputOptions, bundle) {
      const chunkOfModule = new Map();
      const chunks = {};
      const assets = [];
      const entries = {};
      const importers = new Map();

      for (const [fileName, output] of Object.entries(bundle)) {
        if (output.type !== "chunk") {
          if (!/\.(map|br)$/.test(fileName)) {
            assets.push(fileName);
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
          examples[`${kind}:${targetFile}`] ??= {
            from: normalize(from),
            to: normalize(to),
          };
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
          kind: chunk.isEntry
            ? "entry"
            : chunk.isDynamicEntry
              ? "lazy"
              : "shared",
          facade: chunk.facadeModuleId ? normalize(chunk.facadeModuleId) : null,
          imports: chunk.imports,
          dynamicImports: chunk.dynamicImports.filter(
            (file) => file !== fileName
          ),
          urlImports: Object.keys(examples)
            .filter((key) => key.startsWith("url:"))
            .map((key) => key.slice("url:".length)),
          examples,
        };
      }

      this.emitFile({
        type: "asset",
        fileName: "manifest/bundle-graph.json",
        source: JSON.stringify({
          version: 5,
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

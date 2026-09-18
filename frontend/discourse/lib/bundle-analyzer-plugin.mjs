import * as fs from "fs";
import { relative } from "path";

// Brotli sizes are intentionally NOT computed here — brotli at max quality is
// the slowest part of the build. The dev-tools UI computes them on demand in a
// web worker instead (see bundle-analyzer/brotli-sizes.js).

const DYNAMIC_IMPORT_RE =
  /\bimport\s*\(\s*(?:\/\*[\s\S]*?\*\/\s*)*(['"`])([^'"`\n]+?)\1/g;

// rolldown's `chunk.name` keeps the original seed-module name even when
// chunkFileNames renames the file; derive the real label from the filename.
const FILE_NAME_RE = /(?:.*\/)?(.+)-[a-z0-9]+\.digested\.js$/;
function nameFromFile(fileName) {
  const m = fileName.match(FILE_NAME_RE);
  return m ? m[1] : fileName;
}

// The UI labels chunks by their filename stem; match it so an import site
// naming a chunk is recognisable against the cards.
function fileStem(fileName) {
  return fileName.replace(/^assets\/js\//, "").replace(/\.digested\.js$/, "");
}

function offsetToLineCol(text, offset) {
  let line = 1;
  let last = 0;
  for (let i = 0; i < offset; i++) {
    if (text.charCodeAt(i) === 10) {
      line++;
      last = i + 1;
    }
  }
  return { line, column: offset - last + 1 };
}

function rel(id) {
  if (!id) {
    return null;
  }
  // Show third-party deps as their package-relative path (dropping the pnpm
  // store prefix); everything else relative to the build cwd, including sibling
  // workspace packages above it (e.g. ../pretty-text/...).
  const nm = id.lastIndexOf("node_modules/");
  if (nm >= 0) {
    return id.slice(nm);
  }
  return relative(process.cwd(), id);
}

// Records, per resolved module id, the source locations where it is
// dynamically `import()`-ed, so dynamic chunks can be traced back to the exact
// file + line that triggers their download.
export default function bundleAnalyzerPlugin({ devMode } = {}) {
  const sitesByResolvedId = new Map();

  function addSite(resolvedId, site) {
    let list = sitesByResolvedId.get(resolvedId);
    if (!list) {
      list = [];
      sitesByResolvedId.set(resolvedId, list);
    }
    if (
      !list.some((s) => s.importer === site.importer && s.line === site.line)
    ) {
      list.push(site);
    }
  }

  return {
    name: "bundle-analyzer",

    async transform(code, id) {
      let source = code;
      try {
        source = fs.readFileSync(id, "utf8");
      } catch {
        // virtual module: fall back to the transformed code
      }

      if (!source.includes("import(")) {
        return null;
      }

      DYNAMIC_IMPORT_RE.lastIndex = 0;
      let match;
      const pending = [];
      while ((match = DYNAMIC_IMPORT_RE.exec(source))) {
        const specifier = match[2];
        const lineStart = source.lastIndexOf("\n", match.index) + 1;
        const lineText = source.slice(lineStart, match.index);
        if (lineText.includes("@type") || /^\s*[*]/.test(lineText)) {
          continue;
        }
        const { line, column } = offsetToLineCol(source, match.index);
        pending.push({ specifier, line, column });
      }

      await Promise.all(
        pending.map(async ({ specifier, line, column }) => {
          let resolved;
          try {
            resolved = await this.resolve(specifier, id);
          } catch {
            resolved = null;
          }
          if (resolved?.id) {
            addSite(resolved.id, {
              importer: rel(id),
              specifier,
              line,
              column,
            });
          }
        })
      );

      return null;
    },

    async generateBundle(_options, bundle) {
      const chunks = {};
      const entrypoints = [];
      const dynamicEntrypoints = [];

      const chunkList = Object.entries(bundle).filter(
        ([, chunk]) => chunk.type === "chunk"
      );

      // A dynamically-imported module only gets `isDynamicEntry` when it lands
      // in a chunk of its own. Once several dynamic entries share it, its code
      // is merged into a facade-less chunk that is still loaded on demand, so
      // take the import edges as the authority on what is a dynamic entrypoint.
      const dynamicTargets = new Map();
      for (const [fileName, chunk] of chunkList) {
        for (const target of chunk.dynamicImports) {
          if (!dynamicTargets.has(target)) {
            dynamicTargets.set(target, []);
          }
          dynamicTargets.get(target).push(fileName);
        }
      }

      for (const [fileName, chunk] of chunkList) {
        const rawSize = Buffer.byteLength(chunk.code, "utf8");

        const modules = Object.entries(chunk.modules)
          .map(([moduleId, m]) => ({
            id: rel(moduleId),
            renderedLength: m.renderedLength,
          }))
          .sort((a, b) => b.renderedLength - a.renderedLength);

        let importSites = sitesByResolvedId.get(chunk.facadeModuleId) || [];
        if (importSites.length === 0 && chunk.facadeModuleId) {
          const info = this.getModuleInfo(chunk.facadeModuleId);
          importSites = (info?.dynamicImporters || []).map((imp) => ({
            importer: rel(imp),
            specifier: null,
            line: null,
            column: null,
          }));
        }
        // A facade-less chunk has no single module to trace back, so collect the
        // source sites of every module in it that is imported dynamically.
        if (importSites.length === 0) {
          const seen = new Set();
          importSites = Object.keys(chunk.modules)
            .flatMap((moduleId) => sitesByResolvedId.get(moduleId) || [])
            .filter((site) => {
              const key = `${site.importer}:${site.line}`;
              if (seen.has(key)) {
                return false;
              }
              seen.add(key);
              return true;
            });
        }
        // Nothing in the chunk is imported by name, so fall back to the chunks
        // that pull it in.
        if (importSites.length === 0) {
          importSites = (dynamicTargets.get(fileName) || []).map((imp) => ({
            importer: fileStem(imp),
            specifier: null,
            line: null,
            column: null,
          }));
        }

        chunks[fileName] = {
          file: fileName,
          name: nameFromFile(fileName),
          facadeModuleId: rel(chunk.facadeModuleId),
          isEntry: chunk.isEntry,
          isDynamicEntry: chunk.isDynamicEntry,
          rawSize,
          imports: chunk.imports,
          dynamicImports: chunk.dynamicImports,
          moduleCount: modules.length,
          modules,
          importSites,
        };

        if (chunk.isEntry) {
          entrypoints.push(fileName);
        } else if (chunk.isDynamicEntry || dynamicTargets.has(fileName)) {
          dynamicEntrypoints.push(fileName);
        }
      }

      const data = {
        generatedAt: new Date().toISOString(),
        emberEnv: process.env.EMBER_ENV || "development",
        entrypoints,
        dynamicEntrypoints,
        chunks,
      };

      const json = JSON.stringify(data);

      // Co-located with the JS chunks so the dev-tools UI can fetch it relative
      // to its own import.meta.url (assets/js/dev-tools-*.js -> ./bundle-analysis.digested.json).
      // The `.digested.` marker tells Rails/propshaft this is pre-fingerprinted
      // and should be served verbatim rather than hashed (and blocked).
      if (devMode) {
        fs.mkdirSync("./dist/assets/js", { recursive: true });
        fs.writeFileSync(
          "./dist/assets/js/bundle-analysis.digested.json",
          json
        );
      } else {
        this.emitFile({
          type: "asset",
          fileName: "assets/js/bundle-analysis.digested.json",
          source: json,
        });
      }
    },
  };
}

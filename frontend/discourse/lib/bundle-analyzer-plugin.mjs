import { createHash } from "crypto";
import * as fs from "fs";
import { relative } from "path";
import { brotliSizeOf } from "./brotli-assets-plugin.mjs";

// The report describes the finished bundle, so its content only exists once
// every chunk is hashed and named — too late for rolldown to fingerprint it as
// an ordinary asset. Name it from a digest of the report itself, and let the
// manifest carry that name to Rails, which puts it in the page's import map.
export const BUNDLE_ANALYSIS_RE =
  /^assets\/js\/bundle-analysis-\w+\.digested\.json$/;

// Sizes come from whatever `brotli-assets-plugin` compressed earlier in the
// build, so the report shows the transfer size a browser really sees and no
// chunk is compressed twice.

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

const relCache = new Map();

function rel(id) {
  if (!id) {
    return null;
  }
  const cached = relCache.get(id);
  if (cached !== undefined) {
    return cached;
  }
  const result = relUncached(id);
  relCache.set(id, result);
  return result;
}

function relUncached(id) {
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
  return {
    name: "bundle-analyzer",

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

        // Asked per module rather than of the facade, so a chunk several
        // dynamic entries were merged into still names what pulls it in.
        const importers = new Set();
        for (const moduleId of Object.keys(chunk.modules)) {
          for (const imp of this.getModuleInfo(moduleId)?.dynamicImporters ??
            []) {
            importers.add(rel(imp));
          }
        }

        // Nothing inside the chunk records an importer, so name the chunks that
        // pull it in instead.
        const importSites = importers.size
          ? [...importers]
          : (dynamicTargets.get(fileName) ?? []).map(fileStem);

        chunks[fileName] = {
          file: fileName,
          name: nameFromFile(fileName),
          facadeModuleId: rel(chunk.facadeModuleId),
          isEntry: chunk.isEntry,
          isDynamicEntry: chunk.isDynamicEntry,
          rawSize,
          brotliSize: brotliSizeOf(bundle, fileName),
          imports: chunk.imports,
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

      // The `.digested.` marker tells Rails/propshaft the file is pre-fingerprinted
      // and should be served verbatim; the digest in the name is what makes that
      // promise true, so a rebuilt report is a new URL rather than a stale hit.
      const digest = createHash("sha256")
        .update(json)
        .digest("hex")
        .slice(0, 12);
      const fileName = `assets/js/bundle-analysis-${digest}.digested.json`;

      this.emitFile({ type: "asset", fileName, source: json });

      if (devMode) {
        // The dev engine leaves emitted assets unwritten, and keeps the output
        // directory between builds, so clear the reports this one replaces.
        const dir = "./dist/assets/js";
        fs.mkdirSync(dir, { recursive: true });
        for (const stale of fs.readdirSync(dir)) {
          if (BUNDLE_ANALYSIS_RE.test(`assets/js/${stale}`)) {
            fs.rmSync(`${dir}/${stale}`);
          }
        }
        fs.writeFileSync(`./dist/${fileName}`, json);
      }
    },
  };
}

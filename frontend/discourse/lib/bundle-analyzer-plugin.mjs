import { createHash } from "crypto";
import * as fs from "fs";
import { relative } from "path";
import brotli from "./brotli.mjs";

const BUNDLE_ANALYSIS_RE =
  /^assets\/js\/bundle-analysis-\w+\.digested\.json(\.br)?$/;

// rolldown's `chunk.name` keeps the original seed-module name even when
// chunkFileNames renames the file.
const FILE_NAME_RE = /(?:.*\/)?(.+)-[a-z0-9]+\.digested\.js$/;
function nameFromFile(fileName) {
  const m = fileName.match(FILE_NAME_RE);
  return m ? m[1] : fileName;
}

const relCache = new Map();

// A dependency reads better as its package-relative path than as a pnpm store
// path; everything else is relative to the build cwd. Memoised: a module id
// repeats across chunks.
function rel(id) {
  if (!id) {
    return null;
  }

  if (!relCache.has(id)) {
    const nodeModules = id.lastIndexOf("node_modules/");
    relCache.set(
      id,
      nodeModules >= 0 ? id.slice(nodeModules) : relative(process.cwd(), id)
    );
  }

  return relCache.get(id);
}

// Describes the finished bundle: what each chunk weighs, what is inside it, and
// which files dynamically import it. Rails finds the report by name on disk: a
// watching build runs this hook on its own schedule, so neither the manifest nor
// the bundle a later plugin is handed can be relied on to mention it.
export default function bundleAnalyzerPlugin({
  brotliSizes,
  compress,
  pruneStale,
} = {}) {
  let reportFileName;

  return {
    name: "bundle-analyzer",

    async generateBundle(_options, bundle) {
      const chunks = {};
      const entrypoints = [];
      const dynamicEntrypoints = [];

      const chunkList = Object.entries(bundle).filter(
        ([, chunk]) => chunk.type === "chunk"
      );

      // `isDynamicEntry` is set only while a dynamically-imported module has a
      // chunk to itself, so the import edges are the authority instead.
      const dynamicTargets = new Set(
        chunkList.flatMap(([, chunk]) => chunk.dynamicImports)
      );

      for (const [fileName, chunk] of chunkList) {
        const rawSize = Buffer.byteLength(chunk.code, "utf8");

        const modules = Object.entries(chunk.modules)
          .map(([moduleId, m]) => ({
            id: rel(moduleId),
            renderedLength: m.renderedLength,
          }))
          .sort((a, b) => b.renderedLength - a.renderedLength);

        // Per module rather than of the facade, so a chunk that several dynamic
        // entries were merged into still names what pulls it in.
        const importers = new Set();
        for (const moduleId of Object.keys(chunk.modules)) {
          for (const imp of this.getModuleInfo(moduleId)?.dynamicImporters ??
            []) {
            importers.add(rel(imp));
          }
        }

        const importSites = [...importers];

        chunks[fileName] = {
          file: fileName,
          name: nameFromFile(fileName),
          facadeModuleId: rel(chunk.facadeModuleId),
          isEntry: chunk.isEntry,
          isDynamicEntry: chunk.isDynamicEntry,
          rawSize,
          brotliSize: brotliSizes.get(fileName) ?? null,
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
        emberEnv: process.env.EMBER_ENV || "development",
        entrypoints,
        dynamicEntrypoints,
        chunks,
      };

      const json = JSON.stringify(data);

      // `.digested.` promises propshaft the name is a fingerprint, and the report
      // can only be digested once every chunk in it has been.
      const digest = createHash("sha256")
        .update(json)
        .digest("hex")
        .slice(0, 12);
      const fileName = `assets/js/bundle-analysis-${digest}.digested.json`;

      this.emitFile({ type: "asset", fileName, source: json });
      reportFileName = fileName;

      if (compress) {
        this.emitFile({
          type: "asset",
          fileName: `${fileName}.br`,
          source: await brotli(Buffer.from(json, "utf8")),
        });
      }
    },

    // A watching build never clears its output directory, and each report is the
    // size of the bundle it describes. Swept after the write, so the name in the
    // manifest always points at a file that exists.
    writeBundle() {
      const dir = "./dist/assets/js";
      // Without a report of its own, this pass would sweep away the live one.
      if (!pruneStale || !reportFileName || !fs.existsSync(dir)) {
        return;
      }

      for (const entry of fs.readdirSync(dir)) {
        const path = `assets/js/${entry}`;
        if (BUNDLE_ANALYSIS_RE.test(path) && !path.startsWith(reportFileName)) {
          fs.rmSync(`${dir}/${entry}`);
        }
      }
    },
  };
}

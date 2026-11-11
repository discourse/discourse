import { createHash } from "crypto";
import * as fs from "fs";
import brotli from "./brotli.mjs";
import { bundleGraph } from "./bundle-graph.mjs";
import { moduleIdNormalizer } from "./bundle-module-ids.mjs";

const BUNDLE_ANALYSIS_RE = /^bundle-analysis-\w+\.digested\.json(\.br)?$/;

// rolldown's `chunk.name` keeps the original seed-module name even when
// chunkFileNames renames the file.
const FILE_NAME_RE = /(?:.*\/)?(.+)-[a-z0-9]+\.digested\.js$/;
function nameFromFile(fileName) {
  const m = fileName.match(FILE_NAME_RE);
  return m ? m[1] : fileName;
}

// Describes the finished bundle: what each chunk weighs, what is inside it,
// which files dynamically import it and how the chunks connect, which CI
// compares between builds. Written from `writeBundle`, where the
// chunks a browser will fetch are already on disk to be measured; Rails finds
// the report by globbing for its name. `root` makes module ids relative.
export default function bundleAnalyzerPlugin({
  compress,
  root = process.cwd(),
} = {}) {
  const normalize = moduleIdNormalizer(root);

  return {
    name: "bundle-analyzer",

    async writeBundle(options, bundle) {
      const graph = bundleGraph(
        bundle,
        (id) => this.getModuleInfo(id),
        normalize
      );
      const chunks = {};
      const entrypoints = [];
      const dynamicEntrypoints = [];

      // The bundler's iteration order can change between builds of the same
      // input, and the report is digested, so everything in it is sorted.
      const chunkList = Object.entries(bundle)
        .filter(([, chunk]) => chunk.type === "chunk")
        .sort(([a], [b]) => compareStrings(a, b));

      // `isDynamicEntry` is set only while a dynamically-imported module has a
      // chunk to itself, so the import edges are the authority instead.
      const dynamicTargets = new Set(
        chunkList.flatMap(([, chunk]) => chunk.dynamicImports)
      );

      for (const [fileName, chunk] of chunkList) {
        const modules = Object.entries(chunk.modules)
          .map(([moduleId, m]) => ({
            id: normalize(moduleId),
            renderedLength: m.renderedLength,
          }))
          .sort(
            (a, b) =>
              b.renderedLength - a.renderedLength || compareStrings(a.id, b.id)
          );

        chunks[fileName] = {
          file: fileName,
          name: nameFromFile(fileName),
          facadeModuleId: chunk.facadeModuleId
            ? normalize(chunk.facadeModuleId)
            : null,
          isEntry: chunk.isEntry,
          isDynamicEntry: chunk.isDynamicEntry,
          // From disk: reading `chunk.code` copies every chunk out of the bundler.
          rawSize: fileSize(`${options.dir}/${fileName}`),
          brotliSize: fileSize(`${options.dir}/${fileName}.br`),
          imports: [...chunk.imports].sort(),
          modules,
          ...graph.chunks[fileName],
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
        assets: graph.assets,
        moduleIds: graph.moduleIds,
        importers: graph.importers,
      };

      const json = JSON.stringify(data);

      // `.digested.` promises propshaft the name is a fingerprint, and the report
      // can only be digested once every chunk in it has been.
      const digest = createHash("sha256")
        .update(json)
        .digest("hex")
        .slice(0, 12);
      const fileName = `bundle-analysis-${digest}.digested.json`;
      const dir = `${options.dir}/assets/js`;

      fs.writeFileSync(`${dir}/${fileName}`, json);

      if (compress) {
        // Only the dev tools fetch the report; the highest quality would take
        // most of a second on it.
        fs.writeFileSync(
          `${dir}/${fileName}.br`,
          await brotli(Buffer.from(json, "utf8"), 9)
        );
      }

      // A watching build never clears its output directory, and each report is
      // the size of the bundle it describes.
      for (const entry of fs.readdirSync(dir)) {
        if (BUNDLE_ANALYSIS_RE.test(entry) && !entry.startsWith(fileName)) {
          fs.rmSync(`${dir}/${entry}`);
        }
      }
    },
  };
}

function compareStrings(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

function fileSize(path) {
  return fs.statSync(path, { throwIfNoEntry: false })?.size ?? null;
}

import { createHash } from "crypto";
import { relative } from "path";

const PLACEHOLDER = /!~\{[\w$]{1,17}\}~/g;

/*
 * A JS port of rolldown's builtin `chunkImportMap`, which cannot exclude chunks.
 *
 * Before hashing, chunk filename placeholders in code are swapped for names
 * derived from module identity, so one changed chunk does not rename every chunk
 * that imports it. `onImportMap` receives stable-to-real filename pairs.
 * Chunks matching `noImportMap`, and everything they reach, keep real filenames.
 */
export default function chunkImportMapPlugin({
  root,
  noImportMap,
  onImportMap,
}) {
  let state;
  const stabilize = (str) =>
    str.replace(PLACEHOLDER, (p) => state.stableNames.get(p) ?? p);

  return {
    name: "discourse-chunk-import-map",

    renderChunk: {
      order: "post",
      handler(code, chunk, _options, meta) {
        state ??= {
          stableNames: computeStableNames(meta.chunks, root),
          withoutImportMap: computeWithoutImportMap(meta.chunks, noImportMap),
        };
        if (state.withoutImportMap.has(chunk.fileName)) {
          return null;
        }
        return { code: stabilize(code), map: null };
      },
    },

    generateBundle(_options, bundle) {
      const importMap = {};
      for (const chunk of Object.values(bundle)) {
        if (chunk.type === "chunk") {
          const stable = stabilize(chunk.preliminaryFileName);
          if (stable !== chunk.preliminaryFileName) {
            importMap[stable] = chunk.fileName;
          }
        }
      }
      onImportMap(importMap);
      state = null;
    },
  };
}

function computeStableNames(chunks, root) {
  const names = new Map();
  for (const chunk of Object.values(chunks)) {
    const identity = chunk.facadeModuleId ?? [...chunk.moduleIds].sort()[0];
    const hex = createHash("sha256")
      .update(relative(root, identity))
      .digest("hex");
    const hash = BigInt(`0x${hex}`).toString(36);
    for (const placeholder of chunk.fileName.match(PLACEHOLDER) ?? []) {
      names.set(placeholder, hash.slice(0, placeholder.length));
    }
  }
  return names;
}

function computeWithoutImportMap(chunks, noImportMap) {
  const withoutImportMap = new Set();
  const visit = (fileName) => {
    const chunk = chunks[fileName];
    if (chunk && !withoutImportMap.has(fileName)) {
      withoutImportMap.add(fileName);
      [...chunk.imports, ...chunk.dynamicImports].forEach(visit);
    }
  };
  Object.values(chunks)
    .filter(noImportMap)
    .forEach((c) => visit(c.fileName));
  return withoutImportMap;
}

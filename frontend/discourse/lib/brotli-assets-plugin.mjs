import { createHash } from "crypto";
import brotli from "./brotli.mjs";

// Ships a `.br` beside every chunk for nginx to serve under `brotli_static`.
export default function brotliAssetsPlugin({ enabled } = {}) {
  let compressed = new Map();

  return {
    name: "brotli-assets",

    async generateBundle(_outputOptions, bundle) {
      if (!enabled) {
        return;
      }

      const stillHere = new Map();

      await Promise.all(
        Object.entries(bundle)
          .filter(([, item]) => item.type === "chunk")
          .map(async ([fileName, chunk]) => {
            const source = Buffer.from(chunk.code, "utf8");
            const key = createHash("sha256").update(source).digest("hex");
            const br = compressed.get(key) ?? (await brotli(source));

            stillHere.set(key, br);
            this.emitFile({
              type: "asset",
              fileName: `${fileName}.br`,
              source: br,
            });
          })
      );

      // This build's chunks only, so the map does not grow with every edit.
      compressed = stillHere;
    },
  };
}

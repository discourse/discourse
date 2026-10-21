import { createHash } from "crypto";
import { promisify } from "util";
import * as zlib from "zlib";

// Async so the calls run concurrently on the libuv threadpool rather than
// blocking the main thread one chunk at a time.
const brotliCompress = promisify(zlib.brotliCompress);

const EXTENSION = ".br";

/*
 * Compresses every chunk the build emits and ships the result alongside it, for
 * nginx to serve under `brotli_static`. Max quality, matching the compression
 * step that otherwise does this after the build.
 *
 * Each size is recorded in `sizes` as it is measured, so a plugin that runs
 * later can report what a chunk weighs without compressing it again. Handed
 * over directly rather than read back out of the bundle: what an `emitFile`
 * leaves visible to a later plugin varies with the engine running the build.
 */
export default function brotliAssetsPlugin({ enabled, sizes } = {}) {
  // A rebuild hands back every chunk, almost all of them byte for byte, and
  // quality 11 costs far more than digesting the bytes to recognise them.
  let compressed = new Map();

  return {
    name: "brotli-assets",

    async generateBundle(_outputOptions, bundle) {
      if (!enabled) {
        return;
      }

      sizes?.clear();
      const stillHere = new Map();

      await Promise.all(
        Object.entries(bundle)
          .filter(([, item]) => item.type === "chunk")
          .map(async ([fileName, chunk]) => {
            const source = Buffer.from(chunk.code, "utf8");
            const key = createHash("sha256").update(source).digest("hex");
            const br =
              compressed.get(key) ??
              (await brotliCompress(source, {
                params: {
                  [zlib.constants.BROTLI_PARAM_QUALITY]:
                    zlib.constants.BROTLI_MAX_QUALITY,
                  [zlib.constants.BROTLI_PARAM_SIZE_HINT]: source.length,
                },
              }));

            stillHere.set(key, br);
            sizes?.set(fileName, br.length);
            this.emitFile({
              type: "asset",
              fileName: `${fileName}${EXTENSION}`,
              source: br,
            });
          })
      );

      // Holds this build's chunks only, so an afternoon of edits does not pile
      // up every version of every chunk.
      compressed = stillHere;
    },
  };
}

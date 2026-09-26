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
  return {
    name: "brotli-assets",

    async generateBundle(_outputOptions, bundle) {
      if (!enabled) {
        return;
      }

      sizes?.clear();

      await Promise.all(
        Object.entries(bundle)
          .filter(([, item]) => item.type === "chunk")
          .map(async ([fileName, chunk]) => {
            const source = Buffer.from(chunk.code, "utf8");
            const compressed = await brotliCompress(source, {
              params: {
                [zlib.constants.BROTLI_PARAM_QUALITY]:
                  zlib.constants.BROTLI_MAX_QUALITY,
                [zlib.constants.BROTLI_PARAM_SIZE_HINT]: source.length,
              },
            });

            sizes?.set(fileName, compressed.length);
            this.emitFile({
              type: "asset",
              fileName: `${fileName}${EXTENSION}`,
              source: compressed,
            });
          })
      );
    },
  };
}

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
 * A plugin that runs later reads the sizes back out of the bundle with
 * `brotliSizeOf`, so nothing has to compress a chunk twice to measure it.
 */
export default function brotliAssetsPlugin({ enabled } = {}) {
  return {
    name: "brotli-assets",

    async generateBundle(_outputOptions, bundle) {
      if (!enabled) {
        return;
      }

      await Promise.all(
        Object.entries(bundle)
          .filter(([, item]) => item.type === "chunk")
          .map(async ([fileName, chunk]) => {
            const source = Buffer.from(chunk.code, "utf8");

            this.emitFile({
              type: "asset",
              fileName: `${fileName}${EXTENSION}`,
              source: await brotliCompress(source, {
                params: {
                  [zlib.constants.BROTLI_PARAM_QUALITY]:
                    zlib.constants.BROTLI_MAX_QUALITY,
                  [zlib.constants.BROTLI_PARAM_SIZE_HINT]: source.length,
                },
              }),
            });
          })
      );
    },
  };
}

/** Compressed size of a chunk, or null when the build did not compress it. */
export function brotliSizeOf(bundle, fileName) {
  const asset = bundle[`${fileName}${EXTENSION}`];
  return asset ? asset.source.length : null;
}

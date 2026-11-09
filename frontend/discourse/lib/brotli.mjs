import { promisify } from "util";
import * as zlib from "zlib";

const compress = promisify(zlib.brotliCompress);

export default function brotli(source) {
  return compress(source, {
    params: {
      [zlib.constants.BROTLI_PARAM_QUALITY]: zlib.constants.BROTLI_MAX_QUALITY,
      [zlib.constants.BROTLI_PARAM_SIZE_HINT]: source.length,
    },
  });
}

import { promises as fs } from "fs";
import { basename, dirname, resolve } from "path";

const WASM_RE =
  /new URL\(\s*["']([^"']+\.wasm)["']\s*,\s*import\.meta\.url\s*\)/g;

export default function wasmPlugin() {
  return {
    name: "wasm",
    outputOptions(options) {
      const original = options.assetFileNames;
      return {
        ...options,
        assetFileNames: (info) =>
          info.names?.[0]?.endsWith(".wasm")
            ? "assets/wasm/[name]-[hash].digested[extname]"
            : typeof original === "function"
              ? original(info)
              : original,
      };
    },
    transform: {
      filter: {
        code: WASM_RE,
      },
      async handler(code, id) {
        const matches = [...code.matchAll(WASM_RE)];
        if (!matches.length) {
          return null;
        }

        const refs = {};
        for (const [, path] of matches) {
          refs[path] ??= this.emitFile({
            type: "asset",
            name: basename(path),
            source: await fs.readFile(resolve(dirname(id), path)),
          });
        }

        return code.replace(
          WASM_RE,
          (_, path) =>
            `new URL(import.meta.ROLLUP_FILE_URL_${refs[path]}, import.meta.url)`
        );
      },
    },
  };
}

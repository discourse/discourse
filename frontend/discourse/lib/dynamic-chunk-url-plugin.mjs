import { relative } from "path";

const PREFIX = "virtual:dynamic-chunk-url:";
const RESOLVED_PREFIX = "\0" + PREFIX;

/*
 * Importing `virtual:dynamic-chunk-url:<specifier>` emits <specifier> as its own
 * bundled, hashed chunk and resolves to that chunk's final URL (a string). The
 * specifier is resolved like a normal import (relative to the importer).
 *
 * For example, a worker can be started from a blob bootstrap that imports the real
 * chunk by absolute URL, so the worker inherits the host document CSP.
 */
export default function dynamicChunkUrlPlugin() {
  return {
    name: "dynamic-chunk-url",
    resolveId: {
      filter: { id: /^virtual:dynamic-chunk-url:/ },
      async handler(source, importer) {
        const target = source.slice(PREFIX.length);
        const resolved = await this.resolve(target, importer, {
          skipSelf: true,
        });
        if (!resolved) {
          this.error(`dynamic-chunk-url: could not resolve "${target}"`);
        }
        return { id: RESOLVED_PREFIX + resolved.id };
      },
    },
    load: {
      filter: { id: /^\0virtual:dynamic-chunk-url:/ },
      handler(id) {
        const target = id.slice(RESOLVED_PREFIX.length);
        const refId = this.emitFile({
          type: "chunk",
          id: target,
          name: relative(process.cwd(), target)
            .replace(/\.[^.]+$/, "")
            .replace(/[/\\]/g, "-"),
          preserveSignature: "strict",
        });
        return {
          code: `export default import.meta.ROLLUP_FILE_URL_${refId};`,
          moduleType: "js",
        };
      },
    },
  };
}

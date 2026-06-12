// Bundled by rolldown as a standalone chunk (brotli-wasm and its .wasm are
// bundled straight in) and started as a module worker via a blob bootstrap, so
// it inherits the host document CSP. Given a list of chunk URLs, it fetches and
// brotli-compresses each to report its real over-the-wire size — work that used
// to run (slowly) at build time.
import brotliPromise from "brotli-wasm";

let brotli;

self.onmessage = async (e) => {
  const { files } = e.data;
  brotli ||= await brotliPromise;

  for (const { file, url } of files) {
    try {
      const bytes = new Uint8Array(await (await fetch(url)).arrayBuffer());
      const size = brotli.compress(bytes, { quality: 11 }).length;
      postMessage({ file, size });
    } catch (error) {
      postMessage({ file, error: String(error) });
    }
  }

  postMessage({ done: true });
};

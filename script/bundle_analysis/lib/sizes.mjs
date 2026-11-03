import { existsSync, readFileSync, statSync } from "fs";
import { availableParallelism } from "os";
import { join } from "path";
import { Worker } from "worker_threads";
import { brotliCompressSync, constants } from "zlib";

/** Brotli quality 11, which production serves. */
export function brotliSize(buffer) {
  return brotliCompressSync(buffer, {
    params: {
      [constants.BROTLI_PARAM_QUALITY]: 11,
      [constants.BROTLI_PARAM_SIZE_HINT]: buffer.length,
    },
  }).length;
}

/**
 * Brotli sizes of `files` (paths relative to `distDir`). Precompressed `.br`
 * files are used when present; they differ from Node's output by at most a
 * byte. `reuse` maps a file name to a size already computed for an identical
 * file: names carry a content hash, so equal names mean equal content.
 */
export async function brotliSizes(distDir, files, { reuse } = {}) {
  const sizes = new Map();
  const pending = [];

  for (const file of files) {
    const path = join(distDir, file);
    const reused = reuse?.get(file);
    if (reused !== undefined && reused.raw === statSync(path).size) {
      sizes.set(file, reused);
    } else if (existsSync(`${path}.br`)) {
      sizes.set(file, {
        raw: statSync(path).size,
        brotli: statSync(`${path}.br`).size,
      });
    } else {
      pending.push(file);
    }
  }

  const compressed = await compressAll(
    pending.map((file) => join(distDir, file))
  );
  pending.forEach((file, i) => {
    sizes.set(file, {
      raw: statSync(join(distDir, file)).size,
      brotli: compressed[i],
    });
  });
  return sizes;
}

async function compressAll(paths) {
  if (paths.length === 0) {
    return [];
  }
  if (paths.length === 1) {
    return [brotliSize(readFileSync(paths[0]))];
  }

  const results = new Array(paths.length);
  // Largest first, so one big file does not finish last on its own.
  const queue = paths
    .map((path, id) => ({ id, path, size: statSync(path).size }))
    .sort((a, b) => b.size - a.size);
  const workerCount = Math.min(availableParallelism(), queue.length);

  await Promise.all(
    Array.from({ length: workerCount }, async () => {
      const worker = new Worker(
        new URL("./brotli-worker.mjs", import.meta.url)
      );
      try {
        for (let job = queue.shift(); job; job = queue.shift()) {
          results[job.id] = await new Promise((resolve, reject) => {
            worker.once("message", ({ size }) => resolve(size));
            worker.once("error", reject);
            worker.postMessage({ id: job.id, path: job.path });
          });
          worker.removeAllListeners("error");
        }
      } finally {
        await worker.terminate();
      }
    })
  );
  return results;
}

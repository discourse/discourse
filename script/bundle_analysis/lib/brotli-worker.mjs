import { readFileSync } from "fs";
import { parentPort } from "worker_threads";
import { brotliSize } from "./sizes.mjs";

parentPort.on("message", ({ id, path }) => {
  parentPort.postMessage({ id, size: brotliSize(readFileSync(path)) });
});

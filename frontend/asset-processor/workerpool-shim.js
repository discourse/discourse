// Stub for @rollup/plugin-babel's parallel mode (unused); the real workerpool touches worker globals that break mini-racer.
export function pool() {
  throw new Error("workerpool is stubbed out in the asset-processor build");
}

export function worker() {}

export default { pool, worker };

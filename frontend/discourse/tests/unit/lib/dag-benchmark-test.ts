// DAG resolve() caching micro-benchmark.
//
// Question: does the module-level sort cache (fingerprint keying) actually
// beat just re-evaluating the topological sort, for the ~10-element DAGs
// Discourse actually uses (header icons/buttons, post menu, topic columns)?
//
// Requires a one-line hook in app/lib/dag.ts (not for production):
//     let cacheDisabled = false;
//     export function __setDagCacheDisabled(v: boolean) { cacheDisabled = v; }
//   ...honored in resolve() (skip the instance-cache read) and in
//   #resolveKeyOrder() (return this.#sort() directly when cacheDisabled).
//
// Run:  DISCOURSE_DISABLE_BROWSER_SANDBOX=1 bin/qunit --standalone \
//         frontend/discourse/tests/unit/lib/dag-benchmark-test.ts
//
// It reports by throwing a single intentional assertion failure so the
// numbers surface in any reporter (headless/CI included). The "failure" IS
// the report — it is not a real test failure. Not meant to run in CI.
//
// The four regimes are interleaved round-robin and we keep the *minimum*
// per-op time each regime saw across rounds, so a transient machine-load
// spike hits every regime's slow rounds equally and is discarded.

import { module, test } from "qunit";
import DAG, { __setDagCacheDisabled } from "discourse/lib/dag";

// A realistic ~10-element DAG (post-menu-ish): some unconstrained items,
// some { after: X }, some { before: Y }.
function makeEntries(sfx: string): Array<[string, number, object?]> {
  const k = (s: string) => s + sfx;
  return [
    [k("like"), 1],
    [k("copyLink"), 2],
    [k("flag"), 3],
    [k("edit"), 4],
    [k("bookmark"), 5, { after: k("like") }],
    [k("reply"), 6, { after: k("like") }],
    [k("share"), 7, { before: k("flag") }],
    [k("admin"), 8, { after: k("edit") }],
    [k("delete"), 9, { after: k("admin") }],
    [k("showMore"), 10, { before: k("delete") }],
  ];
}

const BATCH = 500; // resolves timed per regime per round
const ROUNDS = 20; // interleaved rounds; min across rounds ignores load

let sink = 0;
let distinctCounter = 0;

function buildIdentical(n: number): DAG<number>[] {
  return Array.from({ length: n }, () => DAG.from(makeEntries("")));
}

function buildDistinct(n: number): DAG<number>[] {
  return Array.from({ length: n }, () =>
    DAG.from(makeEntries("_" + distinctCounter++))
  );
}

// ns per resolve() for one pre-built batch (build is not timed).
function timeBatch(dags: DAG<number>[]): number {
  const t0 = performance.now();
  for (let i = 0; i < dags.length; i++) {
    sink += dags[i].resolve().length;
  }
  const t1 = performance.now();
  return ((t1 - t0) * 1e6) / dags.length;
}

module("Bench | DAG resolve caching", function () {
  test("cache vs re-evaluate (~10 elements, round-robin)", function (assert) {
    // eslint-disable-next-line no-console
    console.error("[dag-bench] test started");

    // Warm up the JIT.
    for (let i = 0; i < 2000; i++) {
      DAG.from(makeEntries(String(i % 3))).resolve();
    }
    // eslint-disable-next-line no-console
    console.error("[dag-bench] warmup done");

    const min = { B: Infinity, C: Infinity, D: Infinity };

    for (let r = 0; r < ROUNDS; r++) {
      // eslint-disable-next-line no-console
      console.error("[dag-bench] round " + (r + 1) + "/" + ROUNDS);
      // B: module-cache hit — fresh instances, identical content (pre-warmed).
      {
        const dags = buildIdentical(BATCH);
        __setDagCacheDisabled(false);
        DAG.from(makeEntries("")).resolve(); // ensure the entry is cached
        min.B = Math.min(min.B, timeBatch(dags));
      }

      // C: module-cache miss — fresh instances, all-distinct content.
      {
        const dags = buildDistinct(BATCH);
        __setDagCacheDisabled(false);
        min.C = Math.min(min.C, timeBatch(dags));
      }

      // D: no cache at all — fresh instances, cache disabled (re-evaluate).
      {
        const dags = buildIdentical(BATCH);
        __setDagCacheDisabled(true);
        min.D = Math.min(min.D, timeBatch(dags));
        __setDagCacheDisabled(false);
      }
    }

    // ops/sec from the best (fastest) round per regime; higher is better.
    const opsB = 1e9 / min.B;
    const opsC = 1e9 / min.C;
    const opsD = 1e9 / min.D;
    const f = (n: number) => Math.round(n).toLocaleString("en-US").padStart(12);
    const table = [
      `DAG resolve() — ops/sec (BATCH=${BATCH}, ROUNDS=${ROUNDS}, best round; higher is better):`,
      `  B module-cache hit  (fresh identical, on):  ${f(opsB)}`,
      `  C module-cache miss (fresh distinct, on):   ${f(opsC)}`,
      `  D no cache          (fresh, cache off):     ${f(opsD)}`,
      ``,
      `  cache HIT  vs re-evaluate:  ${(opsB / opsD).toFixed(2)}x  (>1.0 = cache helps)`,
      `  cache MISS vs re-evaluate:  ${(opsC / opsD).toFixed(2)}x  (<1.0 = cache hurts)`,
    ].join("\n");

    // eslint-disable-next-line no-console
    console.error("[dag-bench] done\n" + table);

    // Report via an intentional failure so the numbers show in any reporter.
    // (sink keeps the resolve() calls from being optimized away.)
    assert.ok(sink > 0, "expected work to run");
    assert.ok(false, "BENCHMARK RESULTS (not a real failure)\n" + table);
  });
});

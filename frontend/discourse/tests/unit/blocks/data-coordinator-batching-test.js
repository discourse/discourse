import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { defineBlockDataSource } from "discourse/blocks";
import {
  blockDataKey,
  loadBlockData,
  resetBlockData,
} from "discourse/lib/blocks/-internals/data-coordinator";
import PreloadStore from "discourse/lib/preload-store";

const SCOPE = "test-outlet";

// A batch-capable source whose hooks record their calls, so tests can assert
// coalescing / extraction / failure routing without a spy library.
function countingBatchSource({ name, resolveBatch, extract } = {}) {
  const calls = {
    requests: [],
    resolves: [],
    extracts: [],
    soloResolves: 0,
  };

  const source = defineBlockDataSource({
    ...(name ? { name } : {}),
    resolve(descriptor, context) {
      calls.soloResolves++;
      return Promise.resolve({ solo: descriptor, context });
    },
    batch: {
      request(descriptors) {
        calls.requests.push(descriptors);
        return { batched: descriptors };
      },
      resolve(payload, options) {
        calls.resolves.push({ payload, options });
        return resolveBatch
          ? resolveBatch(payload, options)
          : Promise.resolve({ response: payload });
      },
      extract(response, descriptor, options) {
        calls.extracts.push({ response, descriptor, options });
        return extract
          ? extract(response, descriptor, options)
          : { extracted: descriptor };
      },
    },
  });

  return { source, calls };
}

// A solo-only source (no batch declaration) with a call counter.
function countingSoloSource({ name } = {}) {
  const calls = { resolves: [] };

  const source = defineBlockDataSource({
    ...(name ? { name } : {}),
    resolve(descriptor, context) {
      calls.resolves.push({ descriptor, context });
      return Promise.resolve({ solo: descriptor });
    },
  });

  return { source, calls };
}

function load(options) {
  return loadBlockData({
    scope: SCOPE,
    dataMeta: { request: (args) => args, source: options.source },
    ...options,
  });
}

module("Unit | Blocks | data-coordinator batching", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetBlockData();
  });

  test("a solo source resolves per descriptor with owner context", async function (assert) {
    const { source, calls } = countingSoloSource();

    const entry = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });

    await entry.promise;

    assert.strictEqual(calls.resolves.length, 1, "solo resolve ran once");
    assert.deepEqual(
      calls.resolves[0].descriptor,
      { filter: "hot" },
      "solo resolve received the descriptor"
    );
    assert.strictEqual(
      calls.resolves[0].context.owner,
      this.owner,
      "solo resolve received the owner"
    );
    assert.deepEqual(entry.data.value, { solo: { filter: "hot" } });
  });

  test("descriptors enqueued in one window coalesce into one batch", async function (assert) {
    const { source, calls } = countingBatchSource();

    const first = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const second = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });

    await Promise.all([first.promise, second.promise]);

    assert.strictEqual(calls.requests.length, 1, "one batch request was built");
    assert.deepEqual(
      calls.requests[0],
      [{ filter: "hot" }, { filter: "latest" }],
      "the batch request received both descriptors in enqueue order"
    );
    assert.strictEqual(calls.resolves.length, 1, "one combined fetch ran");
    assert.strictEqual(
      calls.resolves[0].options.owner,
      this.owner,
      "the combined fetch received the owner"
    );
    assert.strictEqual(calls.extracts.length, 2, "one extract per descriptor");
    assert.deepEqual(
      first.data.value,
      { extracted: { filter: "hot" } },
      "the first entry resolved with its own extracted value"
    );
    assert.deepEqual(
      second.data.value,
      { extracted: { filter: "latest" } },
      "the second entry resolved with its own extracted value"
    );
    assert.strictEqual(calls.soloResolves, 0, "the solo path never ran");
  });

  test("a single pending descriptor still uses the batch path", async function (assert) {
    const { source, calls } = countingBatchSource();

    const entry = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });

    await entry.promise;

    assert.deepEqual(
      calls.requests,
      [[{ filter: "hot" }]],
      "the batch request was built for the single descriptor"
    );
    assert.strictEqual(calls.soloResolves, 0, "the solo path never ran");
    assert.strictEqual(
      calls.extracts[0].options.owner,
      this.owner,
      "extract received the owner"
    );
  });

  test("different sources in one window batch independently", async function (assert) {
    const first = countingBatchSource();
    const second = countingBatchSource();

    const a = load({
      source: first.source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const b = load({
      source: second.source,
      blockName: "featured-users",
      descriptor: { period: "weekly" },
      owner: this.owner,
    });

    await Promise.all([a.promise, b.promise]);

    assert.deepEqual(
      first.calls.requests,
      [[{ filter: "hot" }]],
      "the first source batched only its own descriptor"
    );
    assert.deepEqual(
      second.calls.requests,
      [[{ period: "weekly" }]],
      "the second source batched only its own descriptor"
    );
  });

  test("a named source shares one entry across block kinds", async function (assert) {
    const { source, calls } = countingBatchSource({ name: "topic-list" });

    const fromFeatured = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const fromRecent = load({
      source,
      blockName: "recent-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });

    assert.strictEqual(
      fromFeatured.data,
      fromRecent.data,
      "both block kinds share the same entry for an identical descriptor"
    );

    await fromFeatured.promise;

    assert.deepEqual(
      calls.requests,
      [[{ filter: "hot" }]],
      "the shared descriptor was fetched once"
    );
  });

  test("an unnamed source keys entries per block but still coalesces", async function (assert) {
    const { source, calls } = countingBatchSource();

    const fromFeatured = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const fromRecent = load({
      source,
      blockName: "recent-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });

    assert.notStrictEqual(
      fromFeatured.data,
      fromRecent.data,
      "unnamed sources keep today's per-block cache entries"
    );

    await Promise.all([fromFeatured.promise, fromRecent.promise]);

    assert.strictEqual(
      calls.requests.length,
      1,
      "both entries still resolved through one combined request"
    );
    assert.strictEqual(
      calls.requests[0].length,
      2,
      "the combined request carried both descriptors"
    );
  });

  test("cached entries stay out of later batches", async function (assert) {
    const { source, calls } = countingBatchSource();

    await load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    }).promise;

    const cached = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const fresh = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });

    await Promise.all([cached.promise, fresh.promise]);

    assert.strictEqual(calls.requests.length, 2, "two batch rounds ran");
    assert.deepEqual(
      calls.requests[1],
      [{ filter: "latest" }],
      "the second round carried only the cache miss"
    );
  });

  test("an extract failure rejects only its own entry", async function (assert) {
    const { source, calls } = countingBatchSource({
      extract(response, descriptor) {
        if (descriptor.filter === "latest") {
          throw new Error("missing slice");
        }
        return { extracted: descriptor };
      },
    });

    const healthy = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const broken = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });

    await healthy.promise;
    await assert.rejects(
      broken.promise,
      /missing slice/,
      "the broken entry rejected with the extract error"
    );

    assert.deepEqual(
      healthy.data.value,
      { extracted: { filter: "hot" } },
      "the healthy entry still resolved"
    );

    // The healthy entry stays cached; the broken one was evicted for retry.
    const healthyAgain = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    assert.strictEqual(
      healthyAgain.data,
      healthy.data,
      "the healthy entry is still cached"
    );

    const retried = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });
    assert.notStrictEqual(
      retried.data,
      broken.data,
      "the failed entry was evicted so the retry made a fresh entry"
    );

    await retried.promise.catch(() => {});
    assert.strictEqual(
      calls.requests.length,
      2,
      "the retry went through a new batch round"
    );
  });

  test("a failed combined fetch rejects and evicts every entry", async function (assert) {
    let shouldFail = true;
    const { source, calls } = countingBatchSource({
      resolveBatch() {
        return shouldFail
          ? Promise.reject(new Error("network down"))
          : Promise.resolve({ response: "ok" });
      },
    });

    const first = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });
    const second = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });

    await assert.rejects(first.promise, /network down/, "first rejected");
    await assert.rejects(second.promise, /network down/, "second rejected");

    shouldFail = false;

    const retried = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
    });

    await retried.promise;

    assert.notStrictEqual(retried.data, first.data, "a fresh entry was made");
    assert.strictEqual(calls.requests.length, 2, "the retry refetched");
  });

  test("a preloaded payload bypasses the batch and hydrates via the source", async function (assert) {
    const calls = { requests: [], hydrates: [] };

    const source = defineBlockDataSource({
      name: "topic-list",
      hydrate(raw, options) {
        calls.hydrates.push({ raw, options });
        return { ...raw, hydrated: true };
      },
      batch: {
        request(descriptors) {
          calls.requests.push(descriptors);
          return { batched: descriptors };
        },
        resolve: () => Promise.resolve({}),
        extract: (response, descriptor) => ({ extracted: descriptor }),
      },
    });

    // The preload key for a named source is derived from the source name, not
    // the block name — the contract a server matches when inlining payloads.
    const preloaded = { filter: "hot" };
    PreloadStore.store(blockDataKey("topic-list", preloaded), { raw: true });

    const fromPreload = load({
      source,
      blockName: "featured-topics",
      descriptor: preloaded,
      owner: this.owner,
    });
    const fromNetwork = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
    });

    await Promise.all([fromPreload.promise, fromNetwork.promise]);

    assert.deepEqual(
      fromPreload.data.value,
      { raw: true, hydrated: true },
      "the preloaded entry was hydrated by the source"
    );
    assert.strictEqual(
      calls.hydrates[0].options.owner,
      this.owner,
      "hydrate received the owner"
    );
    assert.deepEqual(
      calls.requests,
      [[{ filter: "latest" }]],
      "only the cache miss entered the batch"
    );
    assert.false(
      PreloadStore.has(blockDataKey("topic-list", preloaded)),
      "the preload key was consumed"
    );
  });

  test("a shared abort signal is forwarded to the combined fetch", async function (assert) {
    const { source, calls } = countingBatchSource();
    const controller = new AbortController();

    const first = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
      signal: controller.signal,
    });
    const second = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
      signal: controller.signal,
    });

    await Promise.all([first.promise, second.promise]);

    assert.strictEqual(
      calls.resolves[0].options.signal,
      controller.signal,
      "the uniform signal reached the combined fetch"
    );
  });

  test("mixed abort signals are not forwarded", async function (assert) {
    const { source, calls } = countingBatchSource();

    const first = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "hot" },
      owner: this.owner,
      signal: new AbortController().signal,
    });
    const second = load({
      source,
      blockName: "featured-topics",
      descriptor: { filter: "latest" },
      owner: this.owner,
      signal: new AbortController().signal,
    });

    await Promise.all([first.promise, second.promise]);

    // Forwarding one item's signal could abort the other item's fetch, so a
    // mixed group fetches without a signal.
    const forwarded = calls.resolves[0].options.signal ?? null;
    assert.strictEqual(forwarded, null, "no signal was forwarded");
  });
});

import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  blockDataKey,
  getBlockData,
  loadBlockData,
  resetBlockData,
} from "discourse/lib/blocks/-internals/data-coordinator";
import PreloadStore from "discourse/lib/preload-store";

const SCOPE = "test-outlet";

// A data declaration whose `resolve` counts its calls, so tests can assert
// caching / dedup / eviction without a spy library.
function countingDataMeta(resultFactory, extra = {}) {
  const meta = {
    calls: 0,
    request: (args) => args,
    resolve(descriptor, context) {
      meta.calls++;
      return resultFactory(descriptor, context);
    },
    ...extra,
  };
  return meta;
}

module("Unit | Blocks | data-coordinator", function (hooks) {
  setupTest(hooks);

  hooks.afterEach(function () {
    resetBlockData();
  });

  test("resolves through the resolver on a miss and caches the result", async function (assert) {
    const dataMeta = countingDataMeta(() => Promise.resolve(["topic"]));

    const first = loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    });
    const second = getBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    });

    assert.strictEqual(
      first.data,
      second,
      "the same TrackedAsyncData instance is shared for an identical descriptor"
    );

    await first.promise;

    assert.strictEqual(dataMeta.calls, 1, "the resolver ran exactly once");
    assert.true(first.data.isResolved, "the result is resolved");
    assert.deepEqual(first.data.value, ["topic"], "exposes the resolved value");
  });

  test("prefers a preloaded payload, hydrates it, and consumes the key", async function (assert) {
    const descriptor = { filter: "hot" };
    const key = blockDataKey("featured-topics", descriptor);
    PreloadStore.store(key, { raw: true });

    const dataMeta = countingDataMeta(() => Promise.resolve("from-network"), {
      hydrate: (raw) => ({ ...raw, hydrated: true }),
    });

    const { data, promise } = loadBlockData({
      scope: SCOPE,
      blockName: "featured-topics",
      descriptor,
      dataMeta,
      owner: this.owner,
    });

    await promise;

    assert.strictEqual(dataMeta.calls, 0, "the resolver did not run");
    assert.deepEqual(
      data.value,
      { raw: true, hydrated: true },
      "the preloaded payload is hydrated"
    );
    assert.false(
      PreloadStore.has(key),
      "the preload key is removed once consumed"
    );
  });

  test("distinct descriptors resolve independently", async function (assert) {
    const dataMeta = countingDataMeta((descriptor) =>
      Promise.resolve(descriptor.filter)
    );

    const latest = loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    });
    const top = loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "top" },
      dataMeta,
      owner: this.owner,
    });

    assert.notStrictEqual(latest.data, top.data, "separate results");

    await Promise.all([latest.promise, top.promise]);

    assert.strictEqual(
      dataMeta.calls,
      2,
      "the resolver ran once per descriptor"
    );
    assert.strictEqual(latest.data.value, "latest");
    assert.strictEqual(top.data.value, "top");
  });

  test("a rejected resolution is evicted so a later request retries", async function (assert) {
    const dataMeta = countingDataMeta(() =>
      dataMeta.calls === 1
        ? Promise.reject(new Error("boom"))
        : Promise.resolve("recovered")
    );

    const failed = loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    });

    await failed.promise.catch(() => {});

    const retried = loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    });

    assert.notStrictEqual(
      failed.data,
      retried.data,
      "a fresh entry is created after the failure was evicted"
    );

    await retried.promise;

    assert.strictEqual(dataMeta.calls, 2, "the resolver ran again on retry");
    assert.strictEqual(retried.data.value, "recovered");
  });

  test("resetBlockData(scope) drops a scope's cached entries", async function (assert) {
    const dataMeta = countingDataMeta(() => Promise.resolve("value"));

    await loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    }).promise;

    resetBlockData(SCOPE);

    await loadBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: { filter: "latest" },
      dataMeta,
      owner: this.owner,
    }).promise;

    assert.strictEqual(
      dataMeta.calls,
      2,
      "the resolver ran again after the scope was reset"
    );
  });

  test("blockDataKey is stable regardless of descriptor key order", function (assert) {
    assert.strictEqual(
      blockDataKey("recent-topics", { a: 1, b: 2 }),
      blockDataKey("recent-topics", { b: 2, a: 1 }),
      "key order does not change the derived key"
    );
    assert.notStrictEqual(
      blockDataKey("recent-topics", { a: 1 }),
      blockDataKey("featured-topics", { a: 1 }),
      "the block name is part of the key"
    );
  });

  test("a null descriptor yields no resolution", function (assert) {
    const dataMeta = countingDataMeta(() => Promise.resolve("value"));

    const result = getBlockData({
      scope: SCOPE,
      blockName: "recent-topics",
      descriptor: null,
      dataMeta,
      owner: this.owner,
    });

    assert.strictEqual(result, null, "returns null for a null descriptor");
    assert.strictEqual(dataMeta.calls, 0, "the resolver did not run");
  });
});

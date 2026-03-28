import { setupTest } from "ember-qunit";
import { module, test } from "qunit";

module("Unit | Service | nested-view-cache", function (hooks) {
  setupTest(hooks);

  function getService(context) {
    return context.owner.lookup("service:nested-view-cache");
  }

  test("save and get basic entry", function (assert) {
    const cache = getService(this);
    cache.save("key1", { data: "hello" });

    const entry = cache.get("key1");
    assert.strictEqual(entry.data, "hello");
    assert.true(entry.timestamp > 0, "timestamp is set on save");
  });

  test("get returns null for missing key", function (assert) {
    const cache = getService(this);
    assert.strictEqual(cache.get("nonexistent"), null);
  });

  test("remove deletes an entry", function (assert) {
    const cache = getService(this);
    cache.save("key1", { data: "hello" });
    cache.remove("key1");
    assert.strictEqual(cache.get("key1"), null);
  });

  test("TTL expiration evicts stale entries on get", function (assert) {
    const cache = getService(this);
    cache.save("old", { data: "stale" });

    // Backdate the timestamp beyond TTL (10 minutes)
    cache._cache.get("old").timestamp = Date.now() - 11 * 60 * 1000;

    assert.strictEqual(cache.get("old"), null);
  });

  test("entries within TTL are returned", function (assert) {
    const cache = getService(this);
    cache.save("fresh", { data: "valid" });

    // Set timestamp to 5 minutes ago (within 10-minute TTL)
    cache._cache.get("fresh").timestamp = Date.now() - 5 * 60 * 1000;

    const entry = cache.get("fresh");
    assert.strictEqual(entry.data, "valid");
  });

  test("evicts oldest entries when exceeding MAX_ENTRIES (15)", function (assert) {
    const cache = getService(this);

    for (let i = 0; i < 16; i++) {
      cache.save(`key${i}`, { data: i });
      // Stagger timestamps so eviction order is deterministic
      cache._cache.get(`key${i}`).timestamp = Date.now() - (16 - i) * 1000;
    }

    // The oldest (key0) should have been evicted
    assert.strictEqual(cache.get("key0"), null);
    assert.notStrictEqual(cache.get("key15"), null, "newest entry is kept");
  });

  test("evicts TTL-expired entries before size check", function (assert) {
    const cache = getService(this);

    // Fill with 14 entries, all expired
    for (let i = 0; i < 14; i++) {
      cache.save(`expired${i}`, { data: i });
      cache._cache.get(`expired${i}`).timestamp = Date.now() - 11 * 60 * 1000;
    }

    // Add 2 fresh entries — this triggers eviction which should clear expired first
    cache.save("fresh1", { data: "a" });
    cache.save("fresh2", { data: "b" });

    assert.notStrictEqual(cache.get("fresh1"), null, "fresh entries survive");
    assert.notStrictEqual(cache.get("fresh2"), null, "fresh entries survive");
    assert.strictEqual(cache._cache.size, 2, "expired entries were evicted");
  });

  test("buildKey with topic ID only", function (assert) {
    const cache = getService(this);
    assert.strictEqual(cache.buildKey(42, {}), "42");
  });

  test("buildKey with sort param", function (assert) {
    const cache = getService(this);
    assert.strictEqual(cache.buildKey(42, { sort: "new" }), "42:s=new");
  });

  test("buildKey with post_number param", function (assert) {
    const cache = getService(this);
    assert.strictEqual(cache.buildKey(42, { post_number: 5 }), "42:p=5");
  });

  test("buildKey with all params", function (assert) {
    const cache = getService(this);
    assert.strictEqual(
      cache.buildKey(42, { sort: "top", post_number: 5, context: 0 }),
      "42:s=top:p=5:c=0"
    );
  });

  test("buildKey includes context=0 (falsy but not null)", function (assert) {
    const cache = getService(this);
    assert.strictEqual(cache.buildKey(42, { context: 0 }), "42:c=0");
  });

  test("consumeTraversal returns true when useNextTransition was called", function (assert) {
    const cache = getService(this);
    cache.useNextTransition();
    assert.true(cache.consumeTraversal());
  });

  test("consumeTraversal resets forceUseCache after consumption", function (assert) {
    const cache = getService(this);
    cache.useNextTransition();
    cache.consumeTraversal();
    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal returns true for navigation API traverse", function (assert) {
    const cache = getService(this);
    cache._lastNavigationType = "traverse";
    assert.true(cache.consumeTraversal());
  });

  test("consumeTraversal returns false for navigation API push", function (assert) {
    const cache = getService(this);
    cache._lastNavigationType = "push";
    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal resets navigation type after check", function (assert) {
    const cache = getService(this);
    cache._lastNavigationType = "traverse";
    cache.consumeTraversal();
    assert.strictEqual(cache._lastNavigationType, null);
  });

  test("consumeTraversal uses popstate fallback within 1s window", function (assert) {
    const cache = getService(this);
    cache._popstateTime = Date.now() - 500; // 500ms ago
    assert.true(cache.consumeTraversal());
  });

  test("consumeTraversal ignores popstate older than 1s", function (assert) {
    const cache = getService(this);
    cache._popstateTime = Date.now() - 1500; // 1.5s ago
    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal returns false with no signals", function (assert) {
    const cache = getService(this);
    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal prefers forceUseCache over navigation type", function (assert) {
    const cache = getService(this);
    cache.useNextTransition();
    cache._lastNavigationType = "push";
    assert.true(
      cache.consumeTraversal(),
      "forceUseCache wins even when nav type is push"
    );
  });
});

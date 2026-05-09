import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";

module("Unit | Service | nested-view-cache", function (hooks) {
  setupTest(hooks);

  let clock;

  hooks.afterEach(function () {
    clock?.restore();
  });

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
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });

    const cache = getService(this);
    cache.save("old", { data: "stale" });

    clock.tick(11 * 60 * 1000);

    assert.strictEqual(cache.get("old"), null);
  });

  test("entries within TTL are returned", function (assert) {
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });

    const cache = getService(this);
    cache.save("fresh", { data: "valid" });

    clock.tick(5 * 60 * 1000);

    const entry = cache.get("fresh");
    assert.strictEqual(entry.data, "valid");
  });

  test("evicts oldest entries when exceeding MAX_ENTRIES (15)", function (assert) {
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });

    const cache = getService(this);

    for (let i = 0; i < 16; i++) {
      cache.save(`key${i}`, { data: i });
      clock.tick(1000);
    }

    assert.strictEqual(cache.get("key0"), null, "oldest entry is evicted");
    assert.notStrictEqual(cache.get("key15"), null, "newest entry is kept");
  });

  test("evicts TTL-expired entries before size check", function (assert) {
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });

    const cache = getService(this);

    for (let i = 0; i < 14; i++) {
      cache.save(`expired${i}`, { data: i });
    }

    clock.tick(11 * 60 * 1000);

    cache.save("fresh1", { data: "a" });
    cache.save("fresh2", { data: "b" });

    assert.notStrictEqual(cache.get("fresh1"), null, "fresh entries survive");
    assert.notStrictEqual(cache.get("fresh2"), null, "fresh entries survive");

    for (let i = 0; i < 14; i++) {
      assert.strictEqual(
        cache.get(`expired${i}`),
        null,
        `expired entry ${i} was evicted`
      );
    }
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

  test("consumeTraversal returns true for popstate within 1s window", function (assert) {
    const cache = getService(this);
    window.dispatchEvent(new PopStateEvent("popstate"));
    assert.true(cache.consumeTraversal());
  });

  test("consumeTraversal returns false for popstate older than 1s", function (assert) {
    clock = sinon.useFakeTimers({ now: Date.now(), shouldAdvanceTime: false });

    const cache = getService(this);
    window.dispatchEvent(new PopStateEvent("popstate"));

    clock.tick(1500);

    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal returns false with no signals", function (assert) {
    const cache = getService(this);
    assert.false(cache.consumeTraversal());
  });

  test("consumeTraversal prefers forceUseCache over navigation type", function (assert) {
    const cache = getService(this);
    cache.useNextTransition();
    assert.true(
      cache.consumeTraversal(),
      "forceUseCache wins even when nav type is push"
    );
  });
});

import { module, test } from "qunit";
import {
  createElementVirtualizer,
  keyFor,
  stableKeyFor,
} from "discourse/ui-kit/lib/virtualizer";

// A deterministic virtualizer over a fake 500px-tall viewport with fixed-height
// rows, so the windowing math can be asserted without a real layout.
function buildVirtualizer(overrides = {}) {
  const scrollElement = {};
  let scrollOffset = overrides.initialOffset ?? 0;

  const virtualizer = createElementVirtualizer({
    count: 1000,
    getScrollElement: () => scrollElement,
    estimateSize: () => 50,
    overscan: 2,
    // Feed fixed geometry synchronously instead of a real ResizeObserver / scroll.
    observeElementRect: (instance, cb) => {
      cb({ width: 300, height: 500 });
      return () => {};
    },
    observeElementOffset: (instance, cb) => {
      cb(scrollOffset, false);
      return () => {};
    },
    scrollToFn: (offset) => {
      scrollOffset = offset;
    },
    ...overrides,
  });

  const cleanup = virtualizer._didMount();
  virtualizer._willUpdate();
  return { virtualizer, cleanup, setOffset: (o) => (scrollOffset = o) };
}

module("Unit | ui-kit | virtualizer", function () {
  test("getTotalSize reflects the full count, not the window", function (assert) {
    const { virtualizer, cleanup } = buildVirtualizer();
    assert.strictEqual(
      virtualizer.getTotalSize(),
      50 * 1000,
      "total size spans all 1000 rows"
    );
    cleanup();
  });

  test("getVirtualItems returns a bounded window at the top", function (assert) {
    const { virtualizer, cleanup } = buildVirtualizer();
    const items = virtualizer.getVirtualItems();

    assert.true(items.length > 0, "renders some rows");
    assert.true(
      items.length < 30,
      `windows a small slice of 1000 rows (got ${items.length})`
    );
    assert.strictEqual(items[0].index, 0, "starts at the first row");
    assert.strictEqual(items[0].start, 0, "first row is at offset 0");
    cleanup();
  });

  test("stableKeyFor is stable across an in-place id mutation", function (assert) {
    // Reproduces the chat send-confirm case: a row object created with a temporary
    // string id, then reconciled to a numeric server id on the SAME object. Keying
    // on `id` would orphan the measured height; object identity must not.
    const message = { id: "staged-guid-abc" };
    const before = stableKeyFor(message);

    message.id = 4213; // server confirmation mutates in place

    assert.strictEqual(
      stableKeyFor(message),
      before,
      "same object keeps its key across id mutation"
    );
  });

  test("stableKeyFor does not collide across objects and primitive items", function (assert) {
    // Object keys come from a bare counter while primitives are returned as-is, so
    // they share one key space: the object handed key N collides with the primitive
    // item N. Keys drive BOTH the engine's measurement cache (keyed by getItemKey)
    // and {{#each key=}}, so a collision aliases row heights and row identity at once.
    const object = {};
    const objectKey = stableKeyFor(object);

    assert.notStrictEqual(
      stableKeyFor(objectKey),
      objectKey,
      "a primitive item equal to an object's key must not resolve to that same key"
    );
  });

  test("stableKeyFor returns an engine-valid key type", function (assert) {
    // virtual-core's Key contract is number | string | bigint. A boolean item is
    // currently passed straight through, which also breaks the .gts key typing.
    const key = stableKeyFor(true);

    assert.true(
      ["number", "string", "bigint"].includes(typeof key),
      `key type must be engine-valid (got ${typeof key})`
    );
  });

  test("stableKeyFor distinguishes different objects and passes primitives through", function (assert) {
    const a = { id: 1 };
    const b = { id: 1 };
    assert.notStrictEqual(
      stableKeyFor(a),
      stableKeyFor(b),
      "distinct objects get distinct keys even with equal ids"
    );
    assert.strictEqual(
      stableKeyFor("row-7"),
      "row-7",
      "primitive is its own key"
    );
    assert.strictEqual(stableKeyFor(42), 42, "number is its own key");
  });

  module("keyFor (@key field)", function () {
    test("keys by the field value when given a field on an object row", function (assert) {
      // Distinct objects with the SAME field value must resolve to the SAME key —
      // that is the whole point: a rebuilt object with a stable id keeps its row.
      assert.strictEqual(
        keyFor({ id: "u-5", n: 1 }, "id"),
        keyFor({ id: "u-5", n: 2 }, "id"),
        "same field value → same key across distinct objects"
      );
      assert.notStrictEqual(
        keyFor({ id: "u-5" }, "id"),
        keyFor({ id: "u-6" }, "id"),
        "different field values → different keys"
      );
    });

    test("with no field, falls back to identity keying", function (assert) {
      const item = { id: "u-5" };
      assert.strictEqual(
        keyFor(item, undefined),
        stableKeyFor(item),
        "no field → same as stableKeyFor(item)"
      );
    });

    test("a nullish or primitive row falls back to identity keying, never throws", function (assert) {
      // The guard: a field name plus a null/primitive row must not attempt property
      // access. It falls back to stableKeyFor, which supports every item shape.
      assert.strictEqual(keyFor(null, "id"), stableKeyFor(null), "null row");
      assert.strictEqual(
        keyFor(undefined, "id"),
        stableKeyFor(undefined),
        "undefined row"
      );
      assert.strictEqual(keyFor(7, "id"), 7, "primitive row keys as itself");
    });

    test("routes the field value through stableKeyFor so a domain value can't collide with a generated key", function (assert) {
      // A field value that looks like a generated object key must be escaped, not
      // taken verbatim, or it could alias a real object's key.
      const objectKey = stableKeyFor({});
      assert.notStrictEqual(
        keyFor({ id: objectKey }, "id"),
        objectKey,
        "a field value equal to a generated object key is escaped, not aliased"
      );
    });
  });
});

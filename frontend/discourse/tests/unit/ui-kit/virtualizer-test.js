import { module, test } from "qunit";
import {
  createElementVirtualizer,
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
});

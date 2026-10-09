import { module, test } from "qunit";
import {
  createElementVirtualizer,
  keyFor,
  pushScrollOffset,
  rangeExtractorWithPins,
  stableKeyFor,
} from "discourse/ui-kit/-internals/windowing/virtualizer";

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
  test("a pushed offset survives the engine's settle", async function (assert) {
    // The engine learns the offset from a closure only its own scroll handler
    // writes, and its debounced settle re-reports that captured value once
    // scrolling stops. `pushScrollOffset` calls the retained callback directly and
    // cannot reach that closure, so the settle looks able to hand the engine back
    // a pre-push offset. It cannot: a push only ever carries the element's own
    // `scrollTop`, and every change to `scrollTop` emits a scroll event that
    // refreshes the closure long before the settle delay elapses. Pinned here
    // because that safety is the ENGINE's behaviour, not ours, so a version bump
    // could remove it. Uses the real adapter, since the shared harness stubs
    // `observeElementOffset` and would bypass the debounce under test.
    const scrollElement = document.createElement("div");
    scrollElement.style.cssText = "height: 500px; overflow-y: auto";
    const inner = document.createElement("div");
    inner.style.height = "50000px";
    scrollElement.appendChild(inner);
    document.body.appendChild(scrollElement);

    try {
      const virtualizer = createElementVirtualizer({
        count: 1000,
        getScrollElement: () => scrollElement,
        estimateSize: () => 50,
        overscan: 2,
      });
      const cleanup = virtualizer._didMount();
      virtualizer._willUpdate();

      // A real scroll, so the engine captures this offset and arms its settle.
      scrollElement.scrollTop = 2000;
      scrollElement.dispatchEvent(new Event("scroll"));
      assert.strictEqual(
        virtualizer.scrollOffset,
        2000,
        "precondition: the engine adopted the scrolled offset"
      );

      // Correct the engine the way the modifier does for an out-of-range offset.
      scrollElement.scrollTop = 1000;
      pushScrollOffset(virtualizer);
      assert.strictEqual(
        virtualizer.scrollOffset,
        1000,
        "precondition: the push was adopted"
      );

      await new Promise((resolve) => setTimeout(resolve, 250));

      // Without this the assertion below can pass by arriving BEFORE the settle it
      // exists to outlast: a longer debounce in a future engine version would make
      // it vacuous rather than failing, which is the opposite of what it guards.
      assert.false(
        virtualizer.isScrolling,
        "precondition: the scroll settle actually ran inside the wait"
      );
      assert.strictEqual(
        virtualizer.scrollOffset,
        1000,
        "the settle did not re-adopt the pre-push offset"
      );
      cleanup();
    } finally {
      scrollElement.remove();
    }
  });

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

  test("measureElement(null) sweeps disconnected rows from the element cache", function (assert) {
    // The modifier calls measureElement(null) on every flush to evict rows the DOM
    // has removed: a ResizeObserver never fires on removal, so without the sweep the
    // cache — and the observer — would retain every row ever scrolled past. The
    // dependency is version-pinned because this sweep semantics could shift between
    // releases, so pin it here.
    const { virtualizer, cleanup } = buildVirtualizer();

    const container = document.createElement("div");
    document.body.appendChild(container);
    const rows = [0, 1, 2].map((index) => {
      const row = document.createElement("div");
      row.setAttribute("data-index", String(index));
      container.appendChild(row);
      virtualizer.measureElement(row);
      return row;
    });

    assert.strictEqual(
      virtualizer.elementsCache.size,
      3,
      "every measured row is cached"
    );

    // Detach one row as an unmount would, then run the sweep.
    rows[1].remove();
    virtualizer.measureElement(null);

    const cached = [...virtualizer.elementsCache.values()];
    assert.strictEqual(
      virtualizer.elementsCache.size,
      2,
      "the sweep evicts the disconnected row"
    );
    assert.false(cached.includes(rows[1]), "the detached node is gone");
    assert.true(
      cached.includes(rows[0]),
      "the first connected row stays cached"
    );
    assert.true(
      cached.includes(rows[2]),
      "the last connected row stays cached"
    );

    container.remove();
    cleanup();
  });

  test("stableKeyFor is stable across an in-place id mutation", function (assert) {
    // Reproduces optimistic insertion: a row created with a temporary client id,
    // then reconciled to the server's id on the SAME object. Keying on `id` would
    // orphan the measured height; object identity must not.
    const row = { id: "staged-guid-abc" };
    const before = stableKeyFor(row);

    row.id = 4213; // server confirmation mutates in place

    assert.strictEqual(
      stableKeyFor(row),
      before,
      "same object keeps its key across id mutation"
    );
  });

  test("stableKeyFor does not collide across objects and primitive items", function (assert) {
    // Generated object keys live in a reserved namespace, and a string item that
    // looks like one is escaped, so a primitive item can never resolve to a live
    // object's key. Keys drive BOTH the engine's measurement cache (keyed by
    // getItemKey) and {{#each key=}}, so a collision would alias row heights and
    // row identity at once.
    const object = {};
    const objectKey = stableKeyFor(object);

    assert.notStrictEqual(
      stableKeyFor(objectKey),
      objectKey,
      "a primitive item equal to an object's key must not resolve to that same key"
    );
  });

  test("stableKeyFor returns an engine-valid key type", function (assert) {
    // The engine's Key contract is number | string | bigint, so every other item
    // shape has to be normalized into one of them.
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

  module("rangeExtractorWithPins", function () {
    // The window this range yields from the engine's default extractor is exactly
    // [10..15]: overscan 0 keeps the expected arrays literal.
    const RANGE = { startIndex: 10, endIndex: 15, overscan: 0, count: 100 };
    const WINDOW = [10, 11, 12, 13, 14, 15];

    test("extras merge into the window in ascending index order", function (assert) {
      const extract = rangeExtractorWithPins(() => [20, 3]);

      assert.deepEqual(
        extract(RANGE),
        [3, ...WINDOW, 20],
        "unsorted extras land sorted around the window"
      );
    });

    test("the callback receives the default window indices and the range", function (assert) {
      let received;
      const extract = rangeExtractorWithPins((indices, range) => {
        received = { indices, range };
        return [];
      });

      extract(RANGE);

      assert.deepEqual(
        [...received.indices],
        WINDOW,
        "the callback sees the overscan-expanded window"
      );
      assert.strictEqual(
        received.range.count,
        RANGE.count,
        "the callback sees the range it is extending"
      );
    });

    test("duplicate extras and window collisions never yield a duplicate index", function (assert) {
      // The engine publishes one measurement per index with zero dedup of its own,
      // so a surviving duplicate becomes a duplicate {{#each}} key downstream. The
      // wall dedupes unconditionally: within the extras and against the window.
      const extract = rangeExtractorWithPins(() => [3, 3, 12, 20, 20]);

      assert.deepEqual(
        extract(RANGE),
        [3, ...WINDOW, 20],
        "each index appears exactly once"
      );
    });

    test("invalid extras are dropped, not merged", function (assert) {
      const extract = rangeExtractorWithPins(() => [
        1.5,
        -1,
        100,
        Number.NaN,
        Number.POSITIVE_INFINITY,
        "7",
        null,
        undefined,
        3,
      ]);

      assert.deepEqual(
        extract(RANGE),
        [3, ...WINDOW],
        "only the integer in [0, count) survives"
      );
    });

    test("an empty or nullish extras result leaves the window unchanged", function (assert) {
      assert.deepEqual(
        rangeExtractorWithPins(() => [])(RANGE),
        WINDOW,
        "no extras → the default window"
      );
      assert.deepEqual(
        rangeExtractorWithPins(() => null)(RANGE),
        WINDOW,
        "a nullish result is treated as no extras"
      );
    });
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

    test("rows whose field value is absent key by identity, not onto one shared key", function (assert) {
      // Normalizing a nullish field value would send every such row to the SAME
      // constant, aliasing their measurements and duplicating their iteration key.
      // Only a DUPLICATE value is the consumer's contract to keep; a MISSING one
      // has to degrade to the identity keying that works for any item shape.
      const a = { name: "first" };
      const b = { name: "second" };

      assert.notStrictEqual(
        keyFor(a, "id"),
        keyFor(b, "id"),
        "two rows both missing the field stay distinct"
      );
      assert.strictEqual(
        keyFor(a, "id"),
        stableKeyFor(a),
        "a missing field falls back to the row's own identity"
      );
      assert.notStrictEqual(
        keyFor({ id: null }, "id"),
        keyFor({ id: null }, "id"),
        "an explicitly null field value is treated the same way"
      );
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

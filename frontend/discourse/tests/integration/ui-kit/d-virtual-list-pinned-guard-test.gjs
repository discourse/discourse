import { tracked } from "@glimmer/tracking";
import { find, render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const VIEWPORT_PX = 320;

// Derived from the geometry, never from the rendered array's own length: an oracle
// built out of that length accepts a single row as "contiguous from the pinned
// index", which is the exact gap these tests exist to catch.
const MIN_MOUNTED_ROWS = Math.ceil(VIEWPORT_PX / ROW_PX);

const estimate = () => ROW_PX;

/**
 * Asserts that the mounted rows are the pinned index followed by an unbroken run
 * tall enough to fill the viewport.
 *
 * Three assertions rather than one `deepEqual`, so a failure names which property
 * broke: too few rows, the wrong starting index, or a hole.
 *
 * @param assert The QUnit assert object for the running test.
 * @param indices The mounted row indices, ascending.
 * @param label Prefix identifying which stage of the test is being checked.
 */
function assertCoversViewportFromZero(assert, indices, label) {
  assert.true(
    indices.length >= MIN_MOUNTED_ROWS,
    `${label}: at least ${MIN_MOUNTED_ROWS} rows mounted to fill the viewport (got ${indices.length}: [${indices}])`
  );
  assert.strictEqual(
    indices[0],
    0,
    `${label}: the run starts at the pinned row`
  );
  assert.deepEqual(
    indices,
    Array.from({ length: indices.length }, (_, i) => i),
    `${label}: the run has no holes (got [${indices}])`
  );
}

class Harness {
  @tracked items;

  constructor(items) {
    this.items = items;
  }
}

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

function renderedIndices() {
  return [...document.querySelectorAll(".d-virtual-list__item")]
    .map((el) => Number(el.dataset.index))
    .sort((a, b) => a - b);
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

// Guards the wall around @pinnedIndices callback output: garbage extras must be
// inert rather than indexing the engine's measurements with a fractional/NaN key
// (which pushes `undefined` and crashes the state signature), and a stale engine
// scroll offset must not open holes between forced indices and the window.
module(
  "Integration | ui-kit | DVirtualList | pinned index guard",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("garbage callback output is inert and does not crash", async function (assert) {
      const items = buildRows(100);
      const garbagePins = () => [1.5, -2, 1000, Number.NaN];

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 400px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{items}}
            @estimateSize={{estimate}}
            @pinnedIndices={{garbagePins}}
            @overscan={{0}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      await scrollTo(ROW_PX * 100);

      assert
        .dom(".d-virtual-list__item")
        .exists("the list renders without crashing on garbage extras");
      assert
        .dom(".d-virtual-list__item[data-index='1']")
        .doesNotExist("a fractional index pins nothing");
      assert
        .dom(".d-virtual-list__item[data-index='0']")
        .doesNotExist("no valid extra means no off-window row");
    });

    // Regression for a reported gap: filtering a large list down to a single match
    // and then widening the filter (e.g. "1356" → backspace → "135") left a visible
    // hole right after the active row. The active row is pinned, and the engine had
    // kept the scroll offset from before the filter shrank the list, so it computed
    // a window far down while the pin force-rendered the active row at the top —
    // the rows between were never mounted. The window must track the element's
    // real (browser-clamped) offset after the set changes, leaving no gap.
    test("a pinned row leaves no gap after the item set shrinks then grows", async function (assert) {
      const h = new Harness(buildRows(30));
      const pinFirst = () => [0];

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 320px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{h.items}}
            @key="id"
            @estimateSize={{estimate}}
            @pinnedIndices={{pinFirst}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      // Scroll away from the pinned row, then filter down to a single match and
      // widen it again — the sequence that stranded the stale offset.
      await scrollTo(ROW_PX * 8);
      h.items = buildRows(1);
      await settled();
      h.items = buildRows(15);
      await settled();

      assertCoversViewportFromZero(
        assert,
        renderedIndices(),
        "after the shrink and regrow"
      );
    });

    // A callback can force SEVERAL off-window indices at once, so a stale offset
    // has more than one forced row to open holes against. The pins must all stay
    // mounted while scrolled away, and a shrink→grow must leave no hole between
    // any pin and the window.
    test("multiple pinned rows stay mounted and leave no gaps after shrink then grow", async function (assert) {
      const h = new Harness(buildRows(60));
      const pinPair = () => [0, 3];

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 320px;
              overflow-y: auto;
            }
          </style>
          <DVirtualList
            @items={{h.items}}
            @key="id"
            @estimateSize={{estimate}}
            @pinnedIndices={{pinPair}}
            @overscan={{0}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      await scrollTo(ROW_PX * 40);

      const indices = renderedIndices();
      assert.true(
        indices.includes(0),
        `the first pinned row stays mounted outside the window (got [${indices}])`
      );
      assert.true(
        indices.includes(3),
        `the second pinned row stays mounted outside the window (got [${indices}])`
      );
      assert.false(
        indices.includes(1),
        "the first row between the pins is not dragged along"
      );
      assert.false(
        indices.includes(2),
        "the second row between the pins is not dragged along"
      );

      h.items = buildRows(1);
      await settled();
      h.items = buildRows(15);
      await settled();

      assertCoversViewportFromZero(
        assert,
        renderedIndices(),
        "across both pins after the shrink and regrow"
      );
    });
  }
);

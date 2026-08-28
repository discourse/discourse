import { findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const ESTIMATE_PX = 40;
const COUNT = 100;

// Rows cycle through four DIFFERENT heights, none of them the estimate. Uniform
// rows would let an implementation that reports one hardcoded height, or that
// attributes a measurement to the wrong row, satisfy every assertion here.
const HEIGHTS = [40, 65, 90, 115];

const estimate = () => ESTIMATE_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
    sizeClass: `row--h${index % HEIGHTS.length}`,
  }));
}

function mountedRows() {
  return findAll(".d-virtual-list__item").sort(
    (a, b) => Number(a.dataset.index) - Number(b.dataset.index)
  );
}

module("Integration | ui-kit | DVirtualList | measurement", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    enableVirtualization();
  });

  hooks.afterEach(function () {
    disableVirtualization();
  });

  test("measured rows grow the total beyond the estimated one", async function (assert) {
    const items = buildRows(COUNT);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
          .row--h0 {
            height: 40px;
          }
          .row--h1 {
            height: 65px;
          }
          .row--h2 {
            height: 90px;
          }
          .row--h3 {
            height: 115px;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @key="id"
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row {{item.sizeClass}}">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const sizer = document.querySelector(".d-virtual-list__sizer");
    const total = parseFloat(sizer.style.height);

    assert.true(
      total > COUNT * ESTIMATE_PX,
      `the sizer total (${total}px) exceeds the all-estimates total (${
        COUNT * ESTIMATE_PX
      }px), so measured heights reached the engine`
    );
  });

  test("measured rows are stacked contiguously at their measured heights", async function (assert) {
    const items = buildRows(COUNT);

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
          .row--h0 {
            height: 40px;
          }
          .row--h1 {
            height: 65px;
          }
          .row--h2 {
            height: 90px;
          }
          .row--h3 {
            height: 115px;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @key="id"
          @estimateSize={{estimate}}
          as |item|
        >
          <div class="row {{item.sizeClass}}">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    const rows = mountedRows();
    assert.true(rows.length > 1, "precondition: several rows are mounted");
    assert.strictEqual(
      getComputedStyle(rows[0]).position,
      "absolute",
      "precondition: rows sit at their virtual offset, not in normal flow"
    );

    // Contiguity, not merely non-overlap. Each row sits exactly where the
    // measured heights of its predecessors put it, so a height attributed to the
    // wrong row, or one uniform guess, shows up as a gap or an overlap.
    const misplaced = [];
    for (let i = 1; i < rows.length; i++) {
      const previous = rows[i - 1].getBoundingClientRect();
      const current = rows[i].getBoundingClientRect();
      const drift = current.top - previous.bottom;
      if (Math.abs(drift) > 1.5) {
        misplaced.push(
          `row ${rows[i].dataset.index} sits ${Math.round(drift)}px from the bottom of row ${rows[i - 1].dataset.index}`
        );
      }
    }

    assert.deepEqual(
      misplaced,
      [],
      "every mounted row starts where its predecessor ends"
    );
  });

  test("estimateSize receives the item and its index together", async function (assert) {
    const items = buildRows(COUNT);
    const seenIndices = [];
    const mismatches = [];
    const recordingEstimate = (item, index) => {
      seenIndices.push(index);
      if (items[index] !== item) {
        mismatches.push(`index ${index} got ${item?.text ?? String(item)}`);
      }
      return ESTIMATE_PX;
    };

    await render(
      <template>
        {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
        <style>
          .d-virtual-list {
            height: 400px;
            overflow-y: auto;
          }
          .row--h0 {
            height: 40px;
          }
          .row--h1 {
            height: 65px;
          }
          .row--h2 {
            height: 90px;
          }
          .row--h3 {
            height: 115px;
          }
        </style>
        <DVirtualList
          @items={{items}}
          @key="id"
          @estimateSize={{recordingEstimate}}
          as |item|
        >
          <div class="row {{item.sizeClass}}">{{item.text}}</div>
        </DVirtualList>
      </template>
    );

    // Without this the test is vacuous: an implementation that ignores
    // `@estimateSize` entirely records no calls and so records no mismatches.
    assert.true(
      seenIndices.length > 0,
      "precondition: the estimate callback was actually consulted"
    );
    assert.deepEqual(
      mismatches,
      [],
      "every estimateSize call paired an item with its own index"
    );
  });
});

import { find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DVirtualList from "discourse/ui-kit/d-virtual-list";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";

const ROW_PX = 40;
const VIEWPORT_PX = 400;
const COUNT = 100;
const THRESHOLD = 8;

// endBand is the first index inside the end band, and the latch only re-arms once
// the range retreats a further EDGE_HYSTERESIS rows past it. Both are derived so
// the fixture states the arithmetic it depends on.
const END_BAND = COUNT - 1 - THRESHOLD;
const VISIBLE_ROWS = VIEWPORT_PX / ROW_PX;

// The scrollTop whose last visible row is `index`.
function scrollTopForEndIndex(index) {
  return (index + 1 - VISIBLE_ROWS) * ROW_PX;
}

const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

async function scrollTo(top) {
  const element = find(".d-virtual-list");
  element.scrollTop = top;
  await triggerEvent(element, "scroll");
}

// Supplemental coverage for the anti-jitter gap, which the oracle in
// edges-test.gjs does not pin: every retreat there overshoots the gap, so the
// whole suite passes with EDGE_HYSTERESIS set to 0.
module(
  "Integration | ui-kit | DVirtualList | edge hysteresis",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("a retreat inside the gap does not re-arm the end edge", async function (assert) {
      const items = buildRows(COUNT);
      const calls = [];
      const onReachEnd = () => calls.push(true);

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
            @key="id"
            @estimateSize={{estimate}}
            @edgeThreshold={{THRESHOLD}}
            @onReachEnd={{onReachEnd}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.strictEqual(calls.length, 0, "the top of the list is not the end");

      await scrollTo(scrollTopForEndIndex(COUNT - 1));
      assert.strictEqual(calls.length, 1, "reaching the end fires once");

      // One row back from the band. Inside the gap, so the latch must hold: this
      // is the jitter case, where a reader nudging the scrollbar at the boundary
      // would otherwise re-fire the consumer's fetch on every wobble.
      await scrollTo(scrollTopForEndIndex(END_BAND - 1));
      await scrollTo(scrollTopForEndIndex(COUNT - 1));

      assert.strictEqual(
        calls.length,
        1,
        "a retreat that stays inside the gap does not re-arm"
      );

      // Past the gap now, so the latch clears and the next arrival fires again.
      await scrollTo(scrollTopForEndIndex(END_BAND - THRESHOLD));
      await scrollTo(scrollTopForEndIndex(COUNT - 1));

      assert.strictEqual(
        calls.length,
        2,
        "a retreat beyond the gap re-arms, and returning fires again"
      );
    });
  }
);

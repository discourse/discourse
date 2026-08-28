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

class Config {
  @tracked threshold;

  constructor(threshold) {
    this.threshold = threshold;
  }
}

// Supplemental regression coverage for a review finding NOT pinned by the
// decorrelated oracle (edges-test.gjs): a runtime change to
// @edgeThreshold must re-arm the edge latches. Kept in a separate file so the
// oracle stays the untouched spec.
module(
  "Integration | ui-kit | DVirtualList | edge threshold reactivity",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("narrowing @edgeThreshold at runtime re-arms the end edge", async function (assert) {
      const items = buildRows(100);
      const calls = [];
      const onReachEnd = (range) => calls.push(range);
      // A wide threshold makes the top of the list already sit in the end band
      // (endBand = 99 - 90 = 9), so mount fires once and latches the end edge.
      const config = new Config(90);

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
            @edgeThreshold={{config.threshold}}
            @onReachEnd={{onReachEnd}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.strictEqual(
        calls.length,
        1,
        "a threshold spanning the whole list reaches the end on mount"
      );

      // The visible range does not move, but the end band narrows to the last
      // eight rows. The narrowed threshold must re-arm the latch even though no
      // scroll (and so no rendering-signature change) accompanies it.
      config.threshold = 8;
      await settled();

      // Jump straight to the true end, past any range that would have re-armed
      // the latch incidentally. With the latch correctly re-armed by the
      // threshold change, entering the narrow end band fires again.
      await scrollTo(ROW_PX * 100);

      assert.strictEqual(
        calls.length,
        2,
        "after narrowing the threshold, reaching the true end re-fires"
      );
    });

    // A threshold is arithmetic on an index, so a non-finite one makes every band
    // comparison false and the edge silently never fires again. The sibling
    // numeric argument @overscan is normalized for the same reason.
    test("a non-finite @edgeThreshold falls back to the default", async function (assert) {
      const items = buildRows(100);
      const calls = [];
      const onReachEnd = (range) => calls.push(range);
      const config = new Config(NaN);

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
            @edgeThreshold={{config.threshold}}
            @onReachEnd={{onReachEnd}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      assert.strictEqual(
        calls.length,
        0,
        "the end is not reached from the top of a 100 row list"
      );

      await scrollTo(ROW_PX * 100);

      assert.strictEqual(
        calls.length,
        1,
        "reaching the end still fires, so the threshold fell back to a usable one"
      );
    });

    test("a negative @edgeThreshold falls back to a reachable band", async function (assert) {
      const items = buildRows(100);
      const calls = [];
      const onReachEnd = (range) => calls.push(range);
      const config = new Config(-5);

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
            @edgeThreshold={{config.threshold}}
            @onReachEnd={{onReachEnd}}
            as |item|
          >
            <div class="row" style="height: 40px">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      await scrollTo(ROW_PX * 100);

      assert.strictEqual(
        calls.length,
        1,
        "a negative threshold cannot push the band out of reach"
      );
    });
  }
);

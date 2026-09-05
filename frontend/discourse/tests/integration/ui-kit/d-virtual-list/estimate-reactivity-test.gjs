import { tracked } from "@glimmer/tracking";
import { find, findAll, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import DVirtualList from "discourse/ui-kit/d-virtual-list";

const COUNT = 500;
const ROW_PX = 40;
const FIRST_ESTIMATE = 40;
const SECOND_ESTIMATE = 80;

// Two distinct STABLE identities. An inline arrow would change identity on every
// render, which busts the engine's memo for an unrelated reason and would hide
// the defect under test.
const estimateSmall = () => FIRST_ESTIMATE;
const estimateLarge = () => SECOND_ESTIMATE;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

class State {
  @tracked estimate = estimateSmall;
}

function sizerHeight() {
  const sizer = find(".d-virtual-list__sizer");
  return sizer ? parseFloat(sizer.style.height) : null;
}

function mountedRows() {
  return findAll(".d-virtual-list__item");
}

module(
  "Integration | ui-kit | DVirtualList | estimate reactivity",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("a changed @estimateSize re-estimates unmeasured rows", async function (assert) {
      // The SAME array instance across the change: the engine keys its measurement
      // memo on the item-key function, which the modifier caches per items array.
      // A fresh array would rebuild that function and invalidate the memo for a
      // reason other than the estimate, so the defect would not surface.
      const items = buildRows(COUNT);
      const state = new State();

      await render(
        <template>
          {{! eslint-disable-next-line ember/template-no-forbidden-elements }}
          <style>
            .d-virtual-list {
              height: 400px;
              overflow-y: auto;
            }
            .row {
              height: 40px;
            }
          </style>
          <DVirtualList
            @items={{items}}
            @key="id"
            @estimateSize={{state.estimate}}
            as |item|
          >
            <div class="row">{{item.text}}</div>
          </DVirtualList>
        </template>
      );

      const before = sizerHeight();
      assert.strictEqual(
        before,
        COUNT * FIRST_ESTIMATE,
        `every row starts at the first estimate (${COUNT * FIRST_ESTIMATE}px)`
      );

      // Rows that mounted have a real measured height and keep it; only the rest
      // fall back to the estimate. Derived here rather than hardcoded so the
      // expectation survives a change in viewport height or overscan.
      const measured = mountedRows().length;
      const expected = measured * ROW_PX + (COUNT - measured) * SECOND_ESTIMATE;

      state.estimate = estimateLarge;
      await settled();

      const after = sizerHeight();

      assert.notStrictEqual(
        after,
        before,
        "the total moves when the estimate changes"
      );
      assert.strictEqual(
        after,
        expected,
        `unmeasured rows take the new estimate (${measured} measured at ${ROW_PX}px, ${
          COUNT - measured
        } estimated at ${SECOND_ESTIMATE}px)`
      );
    });
  }
);

import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/lib/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

function buildRows(count) {
  return Array.from({ length: count }, (_, index) => ({
    id: index,
    text: `row ${index}`,
  }));
}

// Drives the modifier directly rather than through DVirtualList: the published
// payload is what the component consumes, so nothing above it can observe the
// engine objects it hands out.
module(
  "Integration | ui-kit | DVirtualList | published state",
  function (hooks) {
    setupRenderingTest(hooks);

    // The modifier publishes nothing while the render-all fallback is active, and
    // the global harness turns it off for every test.
    hooks.beforeEach(function () {
      enableVirtualization();
    });

    hooks.afterEach(function () {
      disableVirtualization();
    });

    test("the published range is an exact frozen snapshot or null", async function (assert) {
      const populatedStates = [];
      const emptyStates = [];
      const onPopulatedState = (state) => populatedStates.push(state);
      const onEmptyState = (state) => emptyStates.push(state);
      const populatedItems = buildRows(100);
      const emptyItems = [];

      await render(
        <template>
          <div
            class="populated-viewport"
            style="height: 400px; overflow-y: auto"
            {{dVirtualizer
              items=populatedItems
              estimateSize=estimate
              key="id"
              onState=onPopulatedState
            }}
          >
            <div class="d-virtual-list__sizer"></div>
          </div>
          <div
            class="empty-viewport"
            style="height: 400px; overflow-y: auto"
            {{dVirtualizer
              items=emptyItems
              estimateSize=estimate
              key="id"
              onState=onEmptyState
            }}
          >
            <div class="d-virtual-list__sizer"></div>
          </div>
        </template>
      );

      assert.true(
        populatedStates.length > 0,
        "precondition: the populated modifier published state"
      );
      assert.true(
        emptyStates.length > 0,
        "precondition: the empty modifier published state"
      );

      const populatedRange = populatedStates.at(-1).range;
      assert.deepEqual(
        populatedRange,
        { startIndex: 0, endIndex: 9 },
        "the range carries exactly the visible start and end indices"
      );
      assert.true(Object.isFrozen(populatedRange), "the range is frozen");
      assert.strictEqual(
        emptyStates.at(-1).range,
        null,
        "state publishes null when there is no range"
      );
    });

    test("the published window is frozen and detached from the engine's array", async function (assert) {
      const items = buildRows(100);
      const published = [];
      const onState = (state) => published.push(state);

      await render(
        <template>
          <div
            class="viewport"
            style="height: 400px; overflow-y: auto"
            {{dVirtualizer
              items=items
              estimateSize=estimate
              key="id"
              onState=onState
            }}
          >
            <div class="d-virtual-list__sizer"></div>
          </div>
        </template>
      );

      assert.true(
        published.length > 0,
        "precondition: the modifier published a window"
      );

      const { virtualItems } = published.at(-1);
      assert.true(
        virtualItems.length > 0,
        `precondition: the window is not empty (got ${virtualItems.length})`
      );
      assert.true(
        Object.isFrozen(virtualItems),
        "the published window is frozen"
      );
      assert.throws(
        () => virtualItems.push({ index: 999 }),
        /TypeError/,
        "a consumer cannot extend the array the engine memoized"
      );
    });
  }
);

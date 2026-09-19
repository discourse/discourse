import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  disableVirtualization,
  enableVirtualization,
} from "discourse/ui-kit/-internals/windowing/virtualizer";
import dVirtualizer from "discourse/ui-kit/modifiers/d-virtualizer";

const ROW_PX = 40;
const estimate = () => ROW_PX;

class ReSyncState {
  @tracked estimate = estimate;
}

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

    // The existing "re-syncing options does not republish" test counts
    // onVisibleRangeChange, which a SECOND gate suppresses whenever the indices are
    // unchanged, so deleting the signature gate leaves it green. Counting onState
    // publishes on ONE mounted instance observes the signature gate and nothing else.
    test("an identity-only options re-sync does not republish the window", async function (assert) {
      const publishes = [];
      const onState = (state) => publishes.push(state);
      const items = buildRows(100);
      const state = new ReSyncState();

      await render(
        <template>
          <div
            class="resync-viewport"
            style="height: 400px; overflow-y: auto"
            {{dVirtualizer
              items=items
              estimateSize=state.estimate
              key="id"
              onState=onState
            }}
          >
            <div class="d-virtual-list__sizer"></div>
          </div>
        </template>
      );

      const publishesAfterMount = publishes.length;
      assert.true(publishesAfterMount > 0, "precondition: the mount published");

      // A different closure with identical behaviour, on the SAME instance: the
      // options object changes identity while the rendered window does not.
      state.estimate = () => ROW_PX;
      await settled();

      assert.strictEqual(
        publishes.length,
        publishesAfterMount,
        "an options change that moves nothing republishes nothing"
      );
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

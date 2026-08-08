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

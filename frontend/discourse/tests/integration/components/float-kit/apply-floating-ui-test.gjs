import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { render } from "@ember/test-helpers";
import { getPendingWaiterState } from "@ember/test-waiters";
import { module, test } from "qunit";
import applyFloatingUi from "discourse/float-kit/modifiers/apply-floating-ui";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// The waiter `waitForPromise` registers under. Asserting on this name rather than on "some
// waiter is pending" keeps the test from passing because of unrelated pending work.
const PROMISE_WAITER = "@ember/test-waiters:promise-waiter";

module(
  "Integration | Modifier | FloatKit | apply-floating-ui",
  function (hooks) {
    setupRenderingTest(hooks);

    // A float's size comes from positioning, which resolves off a promise. If that promise is
    // outside test settledness, `settled()` returns while the float is still unpositioned and a
    // test reads it at zero size — which is how a virtualized listbox inside a menu came to
    // render an empty window under assertion.
    //
    // Timing cannot be asserted directly without making the test machine-speed dependent, so
    // this pins the invariant instead: at a moment when positioning is definitely still in
    // flight, the promise must be registered with the waiter system. `updatePosition` invokes
    // the `computePosition` option after floating-ui resolves but before it resolves itself,
    // which is exactly such a moment.
    test("positioning is part of test settledness", async function (assert) {
      let waiterPendingDuringPositioning = null;

      class Host extends Component {
        @tracked instance = null;

        options = {
          computePosition: () => {
            waiterPendingDuringPositioning =
              PROMISE_WAITER in getPendingWaiterState().waiters;
          },
        };

        @action
        captureTrigger(element) {
          // Stands in for a FloatKitInstance: the modifier reads `trigger` and
          // `triggerElement`, and assigns `content` itself.
          this.instance = {
            trigger: element,
            triggerElement: element,
            content: null,
          };
        }

        <template>
          <div {{didInsert this.captureTrigger}}></div>

          {{#if this.instance}}
            <div
              {{applyFloatingUi
                this.instance.trigger
                this.options
                this.instance
              }}
            ></div>
          {{/if}}
        </template>
      }

      await render(<template><Host /></template>);

      assert.notStrictEqual(
        waiterPendingDuringPositioning,
        null,
        "positioning ran, so the assertion below observed a real in-flight moment"
      );
      assert.true(
        waiterPendingDuringPositioning,
        "the positioning promise is registered with the waiter system while in flight, so settled() cannot resolve ahead of it"
      );
    });
  }
);

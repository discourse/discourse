import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { render, settled } from "@ember/test-helpers";
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

    // A float can be re-anchored while open by assigning a new trigger. The modifier then
    // re-runs and subscribes floating-ui's `autoUpdate` to the new trigger; the subscription
    // on the old one has to go with it, or the float keeps repositioning for an element it
    // no longer follows, one leaked observer per swap.
    test("re-anchoring drops the observers on the previous trigger", async function (assert) {
      let positioned = 0;
      let host;

      class Host extends Component {
        @tracked instance = null;

        options = {
          autoUpdate: true,
          computePosition: () => positioned++,
        };

        constructor() {
          super(...arguments);
          host = this;
        }

        @action
        captureTriggers(element) {
          const [first] = element.querySelectorAll("[data-trigger]");
          this.instance = {
            trigger: first,
            triggerElement: first,
            content: null,
          };
        }

        @action
        anchorTo(element) {
          this.instance = {
            ...this.instance,
            trigger: element,
            triggerElement: element,
          };
        }

        <template>
          <div {{didInsert this.captureTriggers}}>
            <div data-trigger="a" style="width: 20px; height: 20px;"></div>
            <div data-trigger="b" style="width: 20px; height: 20px;"></div>
          </div>

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

      // `autoUpdate` reports through ResizeObserver, which delivers after layout, past
      // `settled()`. Two frames is when a size change made in this task has been observed.
      const observed = () =>
        new Promise((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(resolve))
        );

      await render(<template><Host /></template>);
      const first = document.querySelector("[data-trigger='a']");
      const second = document.querySelector("[data-trigger='b']");

      host.anchorTo(second);
      await settled();
      await observed();

      const beforeOldResize = positioned;
      first.style.width = "40px";
      await observed();
      assert.strictEqual(
        positioned,
        beforeOldResize,
        "resizing the trigger the float left behind no longer repositions it"
      );

      const beforeNewResize = positioned;
      second.style.width = "40px";
      await observed();
      assert.true(
        positioned > beforeNewResize,
        "resizing the current trigger still repositions it, so the assertion above is not vacuous"
      );
    });
  }
);

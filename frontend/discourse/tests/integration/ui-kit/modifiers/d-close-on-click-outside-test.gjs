import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { render, settled, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dCloseOnClickOutside from "discourse/ui-kit/modifiers/d-close-on-click-outside";

module(
  "Integration | ui-kit | Modifier | dCloseOnClickOutside",
  function (hooks) {
    setupRenderingTest(hooks);

    test("calls the close function with the event on a pointerdown outside", async function (assert) {
      const events = [];
      const close = (event) => events.push(event);

      await render(
        <template>
          <div class="panel" {{dCloseOnClickOutside close}}>Panel</div>
          <div class="outside">Outside</div>
        </template>
      );

      await triggerEvent(".outside", "pointerdown");

      assert.strictEqual(events.length, 1, "the close function is called once");
      assert.strictEqual(
        events[0].target,
        document.querySelector(".outside"),
        "it receives the pointerdown event"
      );
    });

    test("ignores a pointerdown inside the element", async function (assert) {
      let calls = 0;
      const close = () => calls++;

      await render(
        <template>
          <div class="panel" {{dCloseOnClickOutside close}}>
            <span class="inside">Inside</span>
          </div>
        </template>
      );

      await triggerEvent(".inside", "pointerdown");

      assert.strictEqual(calls, 0, "the close function is not called");
    });

    test("ignores a pointerdown inside the target element", async function (assert) {
      let calls = 0;
      const close = () => calls++;
      const target = document.createElement("div");
      target.className = "detached-target";

      await render(
        <template>
          <div
            class="panel"
            {{dCloseOnClickOutside close (hash target=target)}}
          >
            Panel
          </div>
          <div class="host"></div>
        </template>
      );

      document.querySelector(".host").append(target);
      await triggerEvent(".detached-target", "pointerdown");

      assert.strictEqual(calls, 0, "the close function is not called");
    });

    test("ignores a pointerdown inside the element matching targetSelector", async function (assert) {
      let calls = 0;
      const close = () => calls++;

      await render(
        <template>
          <div
            class="panel"
            {{dCloseOnClickOutside close (hash targetSelector=".related")}}
          >
            Panel
          </div>
          <div class="related"><span class="related-child">Related</span></div>
        </template>
      );

      await triggerEvent(".related-child", "pointerdown");

      assert.strictEqual(calls, 0, "the close function is not called");
    });

    test("ignores a pointerdown inside the element matching secondaryTargetSelector", async function (assert) {
      let calls = 0;
      const close = () => calls++;

      await render(
        <template>
          <div
            class="panel"
            {{dCloseOnClickOutside
              close
              (hash
                targetSelector=".primary" secondaryTargetSelector=".secondary"
              )
            }}
          >
            Panel
          </div>
          <div class="primary">Primary</div>
          <div class="secondary">Secondary</div>
          <div class="outside">Outside</div>
        </template>
      );

      await triggerEvent(".secondary", "pointerdown");
      assert.strictEqual(calls, 0, "the secondary target does not close");

      await triggerEvent(".outside", "pointerdown");
      assert.strictEqual(calls, 1, "an unrelated element still closes");
    });

    test("stops listening when the element is removed", async function (assert) {
      let calls = 0;
      const close = () => calls++;
      const show = tracked(true);

      await render(
        <template>
          {{#if show.value}}
            <div class="panel" {{dCloseOnClickOutside close}}>Panel</div>
          {{/if}}
          <div class="outside">Outside</div>
        </template>
      );

      show.value = false;
      await settled();
      await triggerEvent(".outside", "pointerdown");

      assert.strictEqual(calls, 0, "the close function is not called");
    });
  }
);

import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

module("Integration | ui-kit | d-pointer-drag", function (hooks) {
  setupRenderingTest(hooks);

  test("dispatches down → move → up and toggles the dragging class", async function (assert) {
    const calls = [];
    const onDown = () => calls.push("down");
    const onMove = (event) => calls.push(`move:${event.clientX}`);
    const onUp = () => calls.push("up");

    await render(
      <template>
        <div
          class="dpd-target"
          {{dPointerDrag
            onDown=onDown
            onMove=onMove
            onUp=onUp
            draggingClass="--dragging"
          }}
        ></div>
      </template>
    );

    await triggerEvent(".dpd-target", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
      clientY: 0,
    });
    assert
      .dom(".dpd-target")
      .hasClass("--dragging", "adds the dragging class on a started press");

    await triggerEvent(".dpd-target", "pointermove", {
      pointerId: 1,
      clientX: 12,
      clientY: 0,
    });
    await triggerEvent(".dpd-target", "pointerup", {
      pointerId: 1,
      clientX: 12,
      clientY: 0,
    });

    assert.deepEqual(
      calls,
      ["down", "move:12", "up"],
      "fires the lifecycle in order"
    );
    assert
      .dom(".dpd-target")
      .doesNotHaveClass("--dragging", "removes the dragging class on release");
  });

  test("ignores non-primary buttons", async function (assert) {
    const calls = [];
    const onDown = () => calls.push("down");

    await render(
      <template>
        <div class="dpd-target" {{dPointerDrag onDown=onDown}}></div>
      </template>
    );

    await triggerEvent(".dpd-target", "pointerdown", {
      button: 2,
      pointerId: 1,
    });
    assert.deepEqual(
      calls,
      [],
      "a secondary-button press does not start a drag"
    );
  });

  test("onDown can veto the drag", async function (assert) {
    const calls = [];
    const onDown = () => {
      calls.push("down");
      return false;
    };
    const onMove = () => calls.push("move");

    await render(
      <template>
        <div
          class="dpd-target"
          {{dPointerDrag onDown=onDown onMove=onMove}}
        ></div>
      </template>
    );

    await triggerEvent(".dpd-target", "pointerdown", {
      button: 0,
      pointerId: 1,
      clientX: 0,
    });
    await triggerEvent(".dpd-target", "pointermove", {
      pointerId: 1,
      clientX: 5,
    });

    assert.deepEqual(
      calls,
      ["down"],
      "a false return from onDown aborts the drag; no move fires"
    );
  });
});

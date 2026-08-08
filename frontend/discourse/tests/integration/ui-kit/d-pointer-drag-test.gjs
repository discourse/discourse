import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dPointerDrag from "discourse/ui-kit/modifiers/d-pointer-drag";

module("Integration | ui-kit | d-pointer-drag", function (hooks) {
  setupRenderingTest(hooks);

  test("dispatches start → drag → end and toggles the dragging class", async function (assert) {
    const calls = [];
    const onDragStart = () => calls.push("start");
    const onDrag = (event) => calls.push(`drag:${event.clientX}`);
    const onDragEnd = () => calls.push("end");

    await render(
      <template>
        <div
          class="dpd-target"
          {{dPointerDrag
            onDragStart=onDragStart
            onDrag=onDrag
            onDragEnd=onDragEnd
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
      ["start", "drag:12", "end"],
      "fires the lifecycle in order"
    );
    assert
      .dom(".dpd-target")
      .doesNotHaveClass("--dragging", "removes the dragging class on release");
  });

  test("ignores non-primary buttons", async function (assert) {
    const calls = [];
    const onDragStart = () => calls.push("start");

    await render(
      <template>
        <div class="dpd-target" {{dPointerDrag onDragStart=onDragStart}}></div>
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

  test("onDragStart can veto the drag", async function (assert) {
    const calls = [];
    const onDragStart = () => {
      calls.push("start");
      return false;
    };
    const onDrag = () => calls.push("drag");

    await render(
      <template>
        <div
          class="dpd-target"
          {{dPointerDrag onDragStart=onDragStart onDrag=onDrag}}
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
      ["start"],
      "a false return from onDragStart aborts the drag; no drag fires"
    );
  });
});

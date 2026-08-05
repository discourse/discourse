import { clearRender, find, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dPointerDrag, * as dPointerDragModule from "discourse/ui-kit/modifiers/d-pointer-drag";

function installPointerCaptureSpy(element) {
  const captured = new Set();
  const released = [];

  element.setPointerCapture = (pointerId) => captured.add(pointerId);
  element.hasPointerCapture = (pointerId) => captured.has(pointerId);
  element.releasePointerCapture = (pointerId) => {
    captured.delete(pointerId);
    released.push(pointerId);
  };

  return { captured, released };
}

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

  module("configurable pointer lifecycle", function () {
    test("exports registerPointerDrag for lifecycle reuse", function (assert) {
      assert.strictEqual(
        typeof dPointerDragModule.registerPointerDrag,
        "function",
        "consumers can share the pointer lifecycle without installing the modifier"
      );
    });

    test("a pointer capture failure does not block a later press", async function (assert) {
      const starts = [];
      const onDragStart = (event) => starts.push(event.pointerId);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag onDragStart=onDragStart}}
          ></div>
        </template>
      );

      await triggerEvent(".dpd-target", "pointerdown", {
        button: 0,
        pointerId: 1,
      });
      await triggerEvent(".dpd-target", "pointerdown", {
        button: 0,
        pointerId: 2,
      });

      assert.deepEqual(
        starts,
        [1, 2],
        "a later press can start after pointer capture fails"
      );
    });

    test("threshold suppresses movement until exceeded and stays engaged", async function (assert) {
      const moves = [];
      const onDrag = (event) => moves.push(event.clientX);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag threshold=5 onDrag=onDrag}}
          ></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);

      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(target, "pointermove", {
        pointerId: 1,
        clientX: 4,
        clientY: 0,
      });
      await triggerEvent(target, "pointermove", {
        pointerId: 1,
        clientX: 6,
        clientY: 0,
      });
      await triggerEvent(target, "pointermove", {
        pointerId: 1,
        clientX: 2,
        clientY: 0,
      });

      assert.deepEqual(
        moves,
        [6, 2],
        "a below-threshold move is suppressed, the crossing move is reported, and later moves remain engaged"
      );
    });

    test("stopPropagation defaults off and can be enabled", async function (assert) {
      const ancestorEvents = [];
      const prevented = [];

      await render(
        <template>
          <div class="dpd-ancestor">
            <div class="dpd-default" {{dPointerDrag}}></div>
            <div
              class="dpd-stopped"
              {{dPointerDrag stopPropagation=true}}
            ></div>
          </div>
        </template>
      );

      const ancestor = find(".dpd-ancestor");
      const defaultTarget = find(".dpd-default");
      const stoppedTarget = find(".dpd-stopped");
      installPointerCaptureSpy(defaultTarget);
      installPointerCaptureSpy(stoppedTarget);
      ancestor.addEventListener("pointerdown", (event) => {
        ancestorEvents.push(event.target.className);
      });
      defaultTarget.addEventListener("pointerdown", (event) => {
        prevented.push(event.defaultPrevented);
      });
      stoppedTarget.addEventListener("pointerdown", (event) => {
        prevented.push(event.defaultPrevented);
      });

      await triggerEvent(defaultTarget, "pointerdown", {
        button: 0,
        pointerId: 1,
      });
      await triggerEvent(stoppedTarget, "pointerdown", {
        button: 0,
        pointerId: 2,
      });

      assert.deepEqual(
        ancestorEvents,
        ["dpd-default"],
        "the default press bubbles while the opted-in press does not"
      );
      assert.deepEqual(
        prevented,
        [true, true],
        "both propagation modes still prevent the browser default"
      );
    });

    test("cancelCommits chooses whether cancellation commits", async function (assert) {
      const calls = [];
      const cancelOnCancel = (event) =>
        calls.push(`cancel:cancel:${event.pointerId}`);
      const cancelOnEnd = (event) =>
        calls.push(`end:cancel:${event.pointerId}`);
      const commitOnCancel = (event) =>
        calls.push(`cancel:commit:${event.pointerId}`);
      const commitOnEnd = (event) =>
        calls.push(`end:commit:${event.pointerId}`);

      await render(
        <template>
          <div
            class="dpd-cancel"
            {{dPointerDrag onDragEnd=cancelOnEnd onDragCancel=cancelOnCancel}}
          ></div>
          <div
            class="dpd-commit"
            {{dPointerDrag
              cancelCommits=true
              onDragEnd=commitOnEnd
              onDragCancel=commitOnCancel
            }}
          ></div>
        </template>
      );

      const cancelTarget = find(".dpd-cancel");
      const commitTarget = find(".dpd-commit");
      installPointerCaptureSpy(cancelTarget);
      installPointerCaptureSpy(commitTarget);

      await triggerEvent(cancelTarget, "pointerdown", {
        button: 0,
        pointerId: 1,
      });
      await triggerEvent(cancelTarget, "pointercancel", { pointerId: 1 });
      await triggerEvent(commitTarget, "pointerdown", {
        button: 0,
        pointerId: 2,
      });
      await triggerEvent(commitTarget, "pointercancel", { pointerId: 2 });

      assert.deepEqual(
        calls,
        ["cancel:cancel:1", "end:commit:2"],
        "cancellation only commits when requested"
      );
    });

    test("ignores pointermove from a different pointer", async function (assert) {
      const moves = [];
      const onDrag = (event) => moves.push(event.pointerId);

      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag onDrag=onDrag}}></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 7,
      });
      await triggerEvent(target, "pointermove", { pointerId: 99 });
      await triggerEvent(target, "pointermove", { pointerId: 7 });

      assert.deepEqual(moves, [7], "only the active pointer can move the drag");
    });

    test("ignores pointerup from a different pointer", async function (assert) {
      const ends = [];
      const onDragEnd = (event) => ends.push(event.pointerId);

      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag onDragEnd=onDragEnd}}></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 7,
      });
      await triggerEvent(target, "pointerup", { pointerId: 99 });
      await triggerEvent(target, "pointerup", { pointerId: 7 });

      assert.deepEqual(ends, [7], "only the active pointer can end the drag");
    });

    test("ignores pointercancel from a different pointer", async function (assert) {
      const cancellations = [];
      const onDragCancel = (event) => cancellations.push(event.pointerId);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag onDragCancel=onDragCancel}}
          ></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 7,
      });
      await triggerEvent(target, "pointercancel", { pointerId: 99 });
      await triggerEvent(target, "pointercancel", { pointerId: 7 });

      assert.deepEqual(
        cancellations,
        [7],
        "only the active pointer can cancel the drag"
      );
    });

    test("teardown during a gesture releases pointer capture", async function (assert) {
      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag}}></div>
        </template>
      );

      const target = find(".dpd-target");
      const capture = installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 17,
      });

      await clearRender();

      assert.deepEqual(
        capture.released,
        [17],
        "teardown releases the active pointer"
      );
    });

    test("touchAction is reflected to an attribute and removed on teardown", async function (assert) {
      await render(
        <template>
          <div class="dpd-default" {{dPointerDrag}}></div>
          <div class="dpd-custom" {{dPointerDrag touchAction="pan-y"}}></div>
        </template>
      );

      const defaultTarget = find(".dpd-default");
      const customTarget = find(".dpd-custom");

      assert
        .dom(defaultTarget)
        .hasAttribute(
          "data-pointer-drag",
          "none",
          "the default opts out of browser touch gestures"
        );
      assert
        .dom(customTarget)
        .hasAttribute(
          "data-pointer-drag",
          "pan-y",
          "a custom touch-action value is reflected"
        );

      await clearRender();

      assert.strictEqual(
        defaultTarget.getAttribute("data-pointer-drag"),
        null,
        "the default attribute is removed"
      );
      assert.strictEqual(
        customTarget.getAttribute("data-pointer-drag"),
        null,
        "the custom attribute is removed"
      );
    });
  });
});

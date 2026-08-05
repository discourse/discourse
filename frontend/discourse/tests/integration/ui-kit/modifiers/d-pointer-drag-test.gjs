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

function installEventListenerSpy(element) {
  const added = [];
  const listeners = new Map();
  const removed = [];
  const addEventListener = element.addEventListener.bind(element);
  const removeEventListener = element.removeEventListener.bind(element);

  element.addEventListener = (type, listener, options) => {
    added.push(type);
    listeners.set(type, listener);
    addEventListener(type, listener, options);
  };
  element.removeEventListener = (type, listener, options) => {
    removed.push(type);
    removeEventListener(type, listener, options);
  };

  return { added, listeners, removed };
}

function caughtError(callback) {
  try {
    callback();
  } catch (error) {
    return error;
  }
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

      const target = find(".dpd-target");
      target.setPointerCapture = (pointerId) => {
        // Force the failure: a browser may treat a synthetic pointer ID as an
        // active mouse, so relying on an ambient NotFoundError is unstable.
        if (pointerId === 1) {
          throw new DOMException("No active pointer", "NotFoundError");
        }
      };

      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 1,
      });
      await triggerEvent(target, "pointerdown", {
        button: 0,
        pointerId: 2,
      });

      assert.deepEqual(
        starts,
        [2],
        "only the later press starts after pointer capture fails"
      );
    });

    test("a throwing onDragStart releases capture, rethrows, and permits a later press", function (assert) {
      const target = document.createElement("div");
      const capture = installPointerCaptureSpy(target);
      const events = installEventListenerSpy(target);
      const starts = [];
      const error = new Error("consumer start failed");
      const cleanup = dPointerDragModule.registerPointerDrag(target, () => ({
        onDragStart(event) {
          starts.push(event.pointerId);
          if (event.pointerId === 1) {
            throw error;
          }
        },
      }));

      assert.throws(
        () =>
          events.listeners.get("pointerdown")(
            new PointerEvent("pointerdown", { button: 0, pointerId: 1 })
          ),
        error,
        "the consumer error is rethrown"
      );
      assert.false(
        capture.captured.has(1),
        "a throwing start does not strand its pointer capture"
      );

      events.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 2 })
      );

      assert.deepEqual(
        starts,
        [1, 2],
        "a later press can start after the throwing callback"
      );

      cleanup();
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

    test("lost pointer capture discards and permits a later press by default", async function (assert) {
      const calls = [];
      const onDragStart = (event) => calls.push(`start:${event.pointerId}`);
      const onDragEnd = (event) => calls.push(`end:${event.pointerId}`);
      const onDragCancel = (event) => calls.push(`cancel:${event.pointerId}`);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag
              onDragStart=onDragStart
              onDragEnd=onDragEnd
              onDragCancel=onDragCancel
            }}
          ></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 1 });
      await triggerEvent(target, "lostpointercapture", { pointerId: 1 });
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 2 });
      await triggerEvent(target, "pointerup", { pointerId: 2 });

      assert.deepEqual(
        calls,
        ["start:1", "cancel:1", "start:2", "end:2"],
        "capture loss discards the active drag and clears the gesture latch"
      );
    });

    test("lost pointer capture commits and permits a later press when configured", async function (assert) {
      const calls = [];
      const onDragStart = (event) => calls.push(`start:${event.pointerId}`);
      const onDragEnd = (event) => calls.push(`end:${event.pointerId}`);
      const onDragCancel = (event) => calls.push(`cancel:${event.pointerId}`);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag
              cancelCommits=true
              onDragStart=onDragStart
              onDragEnd=onDragEnd
              onDragCancel=onDragCancel
            }}
          ></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 1 });
      await triggerEvent(target, "lostpointercapture", { pointerId: 1 });
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 2 });
      await triggerEvent(target, "pointerup", { pointerId: 2 });

      assert.deepEqual(
        calls,
        ["start:1", "end:1", "start:2", "end:2"],
        "capture loss commits the active drag and clears the gesture latch"
      );
    });

    test("lost pointer capture ignores other pointers and is harmless after release", async function (assert) {
      const calls = [];
      const onDragStart = (event) => calls.push(`start:${event.pointerId}`);
      const onDragEnd = (event) => calls.push(`end:${event.pointerId}`);
      const onDragCancel = (event) => calls.push(`cancel:${event.pointerId}`);

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag
              onDragStart=onDragStart
              onDragEnd=onDragEnd
              onDragCancel=onDragCancel
            }}
          ></div>
        </template>
      );

      const target = find(".dpd-target");
      installPointerCaptureSpy(target);
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 7 });
      await triggerEvent(target, "lostpointercapture", { pointerId: 99 });
      await triggerEvent(target, "pointerup", { pointerId: 7 });
      await triggerEvent(target, "lostpointercapture", { pointerId: 7 });
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 8 });
      await triggerEvent(target, "lostpointercapture", { pointerId: 8 });

      assert.deepEqual(
        calls,
        ["start:7", "end:7", "start:8", "cancel:8"],
        "only active capture loss terminates a gesture"
      );
    });

    test("teardown removes the lostpointercapture listener", function (assert) {
      const target = document.createElement("div");
      const events = installEventListenerSpy(target);
      const cleanup = dPointerDragModule.registerPointerDrag(
        target,
        () => ({})
      );

      assert.true(
        events.added.includes("lostpointercapture"),
        "capture loss is observed while the gesture is registered"
      );

      cleanup();

      assert.true(
        events.removed.includes("lostpointercapture"),
        "teardown removes the capture-loss listener"
      );
    });

    test("an invalid draggingClass degrades safely through gesture and teardown", function (assert) {
      const target = document.createElement("div");
      const capture = installPointerCaptureSpy(target);
      const events = installEventListenerSpy(target);
      const starts = [];
      const ends = [];
      const cleanup = dPointerDragModule.registerPointerDrag(target, () => ({
        draggingClass: "is-dragging active",
        onDragStart: (event) => starts.push(event.pointerId),
        onDragEnd: (event) => ends.push(event.pointerId),
      }));

      const firstStartError = caughtError(() =>
        events.listeners.get("pointerdown")(
          new PointerEvent("pointerdown", { button: 0, pointerId: 1 })
        )
      );
      assert.false(
        Boolean(firstStartError),
        "an invalid dragging class does not abort gesture start"
      );

      const firstEndError = caughtError(() =>
        events.listeners.get("pointerup")(
          new PointerEvent("pointerup", { pointerId: 1 })
        )
      );
      assert.false(
        Boolean(firstEndError),
        "an invalid dragging class does not abort gesture finish"
      );

      events.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 2 })
      );
      events.listeners.get("pointerup")(
        new PointerEvent("pointerup", { pointerId: 2 })
      );

      assert.deepEqual(
        starts,
        [1, 2],
        "an invalid dragging class does not leave gesture state latched"
      );
      assert.deepEqual(
        ends,
        [1, 2],
        "both gestures remain functional with an invalid dragging class"
      );
      assert.deepEqual(
        [...capture.released],
        [1, 2],
        "both gestures release pointer capture"
      );

      const cleanupError = caughtError(cleanup);
      assert.false(
        Boolean(cleanupError),
        "an invalid dragging class does not abort teardown"
      );
      assert.strictEqual(
        target.getAttribute("data-pointer-drag"),
        null,
        "teardown still removes the pointer-drag attribute"
      );
      assert.deepEqual(
        events.removed,
        [
          "pointerdown",
          "pointermove",
          "pointerup",
          "pointercancel",
          "lostpointercapture",
        ],
        "teardown still removes every pointer listener"
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

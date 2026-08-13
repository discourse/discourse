import { tracked } from "@glimmer/tracking";
import {
  clearRender,
  find,
  render,
  settled,
  triggerEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  stubPointerCapture,
  stubSharedPointerCapture,
} from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import dPointerDrag, * as dPointerDragModule from "discourse/ui-kit/modifiers/d-pointer-drag";

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

  module("focus", function () {
    test("an accepted press and the drag it starts leave focus alone", async function (assert) {
      const onDragStart = () => {};

      await render(
        <template>
          <button type="button" class="dpd-other"></button>
          <button
            type="button"
            class="dpd-target"
            {{dPointerDrag onDragStart=onDragStart}}
          ></button>
        </template>
      );
      stubPointerCapture(".dpd-target");
      find(".dpd-other").focus();

      await triggerEvent(".dpd-target", "pointerdown", {
        button: 0,
        pointerId: 1,
      });
      assert
        .dom(".dpd-other")
        .isFocused(
          "the press takes no focus, so a drag cannot pull the caret out of whatever the user was working in"
        );

      await triggerEvent(".dpd-target", "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 40,
      });
      await triggerEvent(".dpd-target", "pointerup", { pointerId: 1 });
      assert
        .dom(".dpd-other")
        .isFocused("nor does any later phase of the gesture take it");
    });

    test("a press that starts no gesture leaves focus alone", async function (assert) {
      const vetoed = () => false;

      await render(
        <template>
          <button type="button" class="dpd-other"></button>
          <button
            type="button"
            class="dpd-secondary"
            {{dPointerDrag onDragStart=vetoed}}
          ></button>
          <button
            type="button"
            class="dpd-vetoed"
            {{dPointerDrag onDragStart=vetoed}}
          ></button>
        </template>
      );
      stubPointerCapture(".dpd-secondary");
      stubPointerCapture(".dpd-vetoed");
      find(".dpd-other").focus();

      await triggerEvent(".dpd-secondary", "pointerdown", {
        button: 2,
        pointerId: 1,
      });
      assert
        .dom(".dpd-other")
        .isFocused(
          "a secondary-button press starts nothing, so it takes no focus"
        );

      await triggerEvent(".dpd-vetoed", "pointerdown", {
        button: 0,
        pointerId: 2,
      });
      assert
        .dom(".dpd-other")
        .isFocused("a vetoed press starts nothing, so it takes no focus");
    });

    test("a press on an unfocusable handle is harmless", async function (assert) {
      const calls = [];
      const onDragStart = () => calls.push("start");

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag onDragStart=onDragStart}}
          ></div>
        </template>
      );
      stubPointerCapture(".dpd-target");

      await triggerEvent(".dpd-target", "pointerdown", {
        button: 0,
        pointerId: 1,
      });

      assert.deepEqual(calls, ["start"], "the gesture starts as usual");
      assert
        .dom(".dpd-target")
        .isNotFocused("a handle that cannot take focus does not get it");
    });
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
      const capture = stubPointerCapture(target);
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
      stubPointerCapture(target);

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
      stubPointerCapture(defaultTarget);
      stubPointerCapture(stoppedTarget);
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
      stubPointerCapture(cancelTarget);
      stubPointerCapture(commitTarget);

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
      stubPointerCapture(target);
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
      stubPointerCapture(target);
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
      stubPointerCapture(target);
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
      const capture = stubPointerCapture(target);
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
      stubPointerCapture(target);
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
      stubPointerCapture(target);
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
      stubPointerCapture(target);
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
      const capture = stubPointerCapture(target);
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

    test("touchAction is re-reflected when the consumer changes it", async function (assert) {
      const state = new (class {
        @tracked touchAction = "pan-y";
      })();

      await render(
        <template>
          <div
            class="dpd-target"
            {{dPointerDrag touchAction=state.touchAction}}
          ></div>
        </template>
      );

      assert
        .dom(".dpd-target")
        .hasAttribute(
          "data-pointer-drag",
          "pan-y",
          "the initial value is reflected"
        );

      state.touchAction = "pan-x";
      await settled();

      // The declaration has to be in place before a touch begins, so a value
      // changed between gestures has to reach the attribute without the modifier
      // being torn down and rebuilt.
      assert
        .dom(".dpd-target")
        .hasAttribute(
          "data-pointer-drag",
          "pan-x",
          "a later value replaces it without a re-render of the element"
        );
    });
  });

  module("nested registrations claiming one pointer", function () {
    function recorder(calls) {
      return {
        onDragStart: () => calls.push("start"),
        onDragEnd: () => calls.push("end"),
        onDragCancel: () => calls.push("cancel"),
      };
    }

    test("an ancestor claiming the same press releases the descendant's gesture", async function (assert) {
      const inner = [];
      const outer = [];
      const innerHandlers = recorder(inner);
      const outerHandlers = recorder(outer);

      await render(
        <template>
          <div
            class="dpd-outer"
            {{dPointerDrag
              onDragStart=outerHandlers.onDragStart
              onDragEnd=outerHandlers.onDragEnd
              onDragCancel=outerHandlers.onDragCancel
            }}
          >
            <div
              class="dpd-inner"
              {{dPointerDrag
                onDragStart=innerHandlers.onDragStart
                onDragEnd=innerHandlers.onDragEnd
                onDragCancel=innerHandlers.onDragCancel
              }}
            ></div>
          </div>
        </template>
      );

      const outerTarget = find(".dpd-outer");
      const innerTarget = find(".dpd-inner");
      stubPointerCapture(outerTarget);
      stubPointerCapture(innerTarget);

      await triggerEvent(innerTarget, "pointerdown", {
        button: 0,
        pointerId: 1,
      });

      assert.deepEqual(
        inner,
        ["start", "cancel"],
        "the descendant is told its gesture ended when the ancestor takes the pointer"
      );
      assert.deepEqual(
        outer,
        ["start"],
        "the ancestor's gesture is the live one"
      );

      // The release goes to whichever element holds the capture, which is the
      // ancestor — so the descendant sees nothing, exactly as in a real browser
      // once the pointer has left it.
      await triggerEvent(outerTarget, "pointerup", { pointerId: 1 });

      await triggerEvent(innerTarget, "pointerdown", {
        button: 0,
        pointerId: 1,
      });

      assert.deepEqual(
        inner,
        ["start", "cancel", "start", "cancel"],
        "a later press still starts a gesture on the descendant"
      );
      assert.deepEqual(
        outer,
        ["start", "end", "start"],
        "every started gesture reaches exactly one terminal callback"
      );
    });

    test("an ancestor that vetoes the press leaves the descendant's capture in place", async function (assert) {
      const inner = [];
      const innerHandlers = recorder(inner);
      const veto = () => false;

      await render(
        <template>
          <div class="dpd-outer" {{dPointerDrag onDragStart=veto}}>
            <div
              class="dpd-inner"
              {{dPointerDrag
                onDragStart=innerHandlers.onDragStart
                onDragEnd=innerHandlers.onDragEnd
                onDragCancel=innerHandlers.onDragCancel
              }}
            ></div>
          </div>
        </template>
      );

      const innerTarget = find(".dpd-inner");
      // The shared stub, because the subject is exactly the displacement: the
      // ancestor's claim replaces the descendant's pending capture before the
      // veto is known.
      const { ownerOf } = stubSharedPointerCapture([".dpd-outer", innerTarget]);

      await triggerEvent(innerTarget, "pointerdown", {
        button: 0,
        pointerId: 1,
      });

      assert.deepEqual(
        inner,
        ["start"],
        "the descendant's gesture is the live one"
      );
      assert.strictEqual(
        ownerOf(1),
        innerTarget,
        "the capture the veto displaced is handed back to the claimant"
      );

      await triggerEvent(innerTarget, "pointerup", { pointerId: 1 });

      assert.deepEqual(
        inner,
        ["start", "end"],
        "the gesture still reaches its one terminal callback"
      );
    });

    test("a superseded gesture honours cancelCommits", async function (assert) {
      const inner = [];
      const innerHandlers = recorder(inner);

      await render(
        <template>
          <div class="dpd-outer" {{dPointerDrag}}>
            <div
              class="dpd-inner"
              {{dPointerDrag
                onDragStart=innerHandlers.onDragStart
                onDragEnd=innerHandlers.onDragEnd
                onDragCancel=innerHandlers.onDragCancel
                cancelCommits=true
              }}
            ></div>
          </div>
        </template>
      );

      stubPointerCapture(find(".dpd-outer"));
      const innerTarget = find(".dpd-inner");
      stubPointerCapture(innerTarget);

      await triggerEvent(innerTarget, "pointerdown", {
        button: 0,
        pointerId: 3,
      });

      assert.deepEqual(
        inner,
        ["start", "end"],
        "a consumer that commits on cancellation commits here too"
      );
    });

    test("a descendant that stops propagation keeps the pointer", async function (assert) {
      const inner = [];
      const outer = [];
      const innerHandlers = recorder(inner);
      const outerHandlers = recorder(outer);

      await render(
        <template>
          <div
            class="dpd-outer"
            {{dPointerDrag
              onDragStart=outerHandlers.onDragStart
              onDragEnd=outerHandlers.onDragEnd
              onDragCancel=outerHandlers.onDragCancel
            }}
          >
            <div
              class="dpd-inner"
              {{dPointerDrag
                onDragStart=innerHandlers.onDragStart
                onDragEnd=innerHandlers.onDragEnd
                onDragCancel=innerHandlers.onDragCancel
                stopPropagation=true
              }}
            ></div>
          </div>
        </template>
      );

      stubPointerCapture(find(".dpd-outer"));
      const innerTarget = find(".dpd-inner");
      stubPointerCapture(innerTarget);

      await triggerEvent(innerTarget, "pointerdown", {
        button: 0,
        pointerId: 4,
      });
      await triggerEvent(innerTarget, "pointerup", { pointerId: 4 });

      assert.deepEqual(
        inner,
        ["start", "end"],
        "the isolated gesture runs to completion uninterrupted"
      );
      assert.deepEqual(outer, [], "the ancestor never sees the press");
    });

    test("gestures on distinct pointers do not supersede each other", async function (assert) {
      const first = [];
      const second = [];
      const firstHandlers = recorder(first);
      const secondHandlers = recorder(second);

      await render(
        <template>
          <div
            class="dpd-first"
            {{dPointerDrag
              onDragStart=firstHandlers.onDragStart
              onDragEnd=firstHandlers.onDragEnd
              onDragCancel=firstHandlers.onDragCancel
            }}
          ></div>
          <div
            class="dpd-second"
            {{dPointerDrag
              onDragStart=secondHandlers.onDragStart
              onDragEnd=secondHandlers.onDragEnd
              onDragCancel=secondHandlers.onDragCancel
            }}
          ></div>
        </template>
      );

      const firstTarget = find(".dpd-first");
      const secondTarget = find(".dpd-second");
      stubPointerCapture(firstTarget);
      stubPointerCapture(secondTarget);

      await triggerEvent(firstTarget, "pointerdown", {
        button: 0,
        pointerId: 5,
      });
      await triggerEvent(secondTarget, "pointerdown", {
        button: 0,
        pointerId: 6,
      });
      await triggerEvent(firstTarget, "pointerup", { pointerId: 5 });
      await triggerEvent(secondTarget, "pointerup", { pointerId: 6 });

      assert.deepEqual(
        first,
        ["start", "end"],
        "a second pointer elsewhere leaves the first gesture alone"
      );
      assert.deepEqual(
        second,
        ["start", "end"],
        "ownership is tracked per pointer, not globally"
      );
    });

    test("three levels each release the level below them", async function (assert) {
      const inner = [];
      const middle = [];
      const outer = [];
      const innerHandlers = recorder(inner);
      const middleHandlers = recorder(middle);
      const outerHandlers = recorder(outer);

      await render(
        <template>
          <div
            class="dpd-outer"
            {{dPointerDrag
              onDragStart=outerHandlers.onDragStart
              onDragEnd=outerHandlers.onDragEnd
              onDragCancel=outerHandlers.onDragCancel
            }}
          >
            <div
              class="dpd-middle"
              {{dPointerDrag
                onDragStart=middleHandlers.onDragStart
                onDragEnd=middleHandlers.onDragEnd
                onDragCancel=middleHandlers.onDragCancel
              }}
            >
              <div
                class="dpd-inner"
                {{dPointerDrag
                  onDragStart=innerHandlers.onDragStart
                  onDragEnd=innerHandlers.onDragEnd
                  onDragCancel=innerHandlers.onDragCancel
                }}
              ></div>
            </div>
          </div>
        </template>
      );

      for (const selector of [".dpd-outer", ".dpd-middle", ".dpd-inner"]) {
        stubPointerCapture(find(selector));
      }

      await triggerEvent(find(".dpd-inner"), "pointerdown", {
        button: 0,
        pointerId: 11,
      });

      // The middle releasing the inner must not drop the middle's own fresh
      // claim, or the outer would find no owner to release and the middle would
      // stay latched with nothing left to end it.
      assert.deepEqual(inner, ["start", "cancel"], "the innermost is released");
      assert.deepEqual(
        middle,
        ["start", "cancel"],
        "the middle is released too"
      );
      assert.deepEqual(
        outer,
        ["start"],
        "only the outermost keeps the pointer"
      );

      await triggerEvent(find(".dpd-outer"), "pointerup", { pointerId: 11 });
      await triggerEvent(find(".dpd-middle"), "pointerdown", {
        button: 0,
        pointerId: 11,
      });

      assert.deepEqual(
        middle,
        ["start", "cancel", "start", "cancel"],
        "a level released mid-dispatch can start a later gesture"
      );
    });

    test("a registration torn down during onDragStart claims no pointer", function (assert) {
      const target = document.createElement("div");
      stubPointerCapture(target);
      const events = installEventListenerSpy(target);
      const calls = [];
      let cleanup;

      cleanup = dPointerDragModule.registerPointerDrag(target, () => ({
        onDragStart: () => {
          calls.push("start");
          // A consumer destroying its own registration from inside the callback
          // that started it: every listener is gone by the time this returns.
          cleanup();
        },
        onDragCancel: () => calls.push("cancel"),
      }));

      events.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 21 })
      );

      const later = document.createElement("div");
      stubPointerCapture(later);
      const laterEvents = installEventListenerSpy(later);
      const laterCleanup = dPointerDragModule.registerPointerDrag(
        later,
        () => ({})
      );
      laterEvents.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 21 })
      );

      assert.deepEqual(
        calls,
        ["start"],
        "reusing the pointer never reaches into the destroyed registration"
      );

      laterCleanup();
    });

    test("teardown mid-gesture gives up the pointer", function (assert) {
      const target = document.createElement("div");
      stubPointerCapture(target);
      const events = installEventListenerSpy(target);
      const calls = [];

      const cleanup = dPointerDragModule.registerPointerDrag(target, () => ({
        onDragStart: () => calls.push("start"),
        onDragCancel: () => calls.push("cancel"),
      }));

      events.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 22 })
      );
      cleanup();

      const later = document.createElement("div");
      stubPointerCapture(later);
      const laterEvents = installEventListenerSpy(later);
      const laterCleanup = dPointerDragModule.registerPointerDrag(
        later,
        () => ({})
      );
      laterEvents.listeners.get("pointerdown")(
        new PointerEvent("pointerdown", { button: 0, pointerId: 22 })
      );

      assert.deepEqual(
        calls,
        ["start"],
        "a torn-down registration is not asked to release a pointer it no longer holds"
      );

      laterCleanup();
    });
  });

  module("bodyClass", function () {
    test("marks the document body for the gesture's duration", async function (assert) {
      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag bodyClass="dragging"}}></div>
        </template>
      );

      const target = find(".dpd-target");
      stubPointerCapture(target);

      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 1 });
      assert
        .dom(document.body)
        .hasClass("dragging", "the body is marked while the gesture runs");

      await triggerEvent(target, "pointerup", { pointerId: 1 });
      assert
        .dom(document.body)
        .doesNotHaveClass("dragging", "and unmarked on release");
    });

    test("unmarks the body when the gesture is cancelled", async function (assert) {
      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag bodyClass="dragging"}}></div>
        </template>
      );

      const target = find(".dpd-target");
      stubPointerCapture(target);

      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 1 });
      assert.dom(document.body).hasClass("dragging", "the gesture marked it");

      await triggerEvent(target, "pointercancel", { pointerId: 1 });
      assert
        .dom(document.body)
        .doesNotHaveClass(
          "dragging",
          "a cancelled gesture cleans up after itself"
        );
    });

    test("unmarks the body when torn down mid-gesture", async function (assert) {
      await render(
        <template>
          <div class="dpd-target" {{dPointerDrag bodyClass="dragging"}}></div>
        </template>
      );

      const target = find(".dpd-target");
      stubPointerCapture(target);
      await triggerEvent(target, "pointerdown", { button: 0, pointerId: 1 });
      assert.dom(document.body).hasClass("dragging", "the gesture marked it");

      await clearRender();
      assert
        .dom(document.body)
        .doesNotHaveClass("dragging", "teardown does not strand the mark");
    });

    test("a second gesture keeps the mark until it ends too", async function (assert) {
      await render(
        <template>
          <div class="dpd-first" {{dPointerDrag bodyClass="dragging"}}></div>
          <div class="dpd-second" {{dPointerDrag bodyClass="dragging"}}></div>
        </template>
      );

      const first = find(".dpd-first");
      const second = find(".dpd-second");
      stubPointerCapture(first);
      stubPointerCapture(second);

      await triggerEvent(first, "pointerdown", { button: 0, pointerId: 1 });
      await triggerEvent(second, "pointerdown", { button: 0, pointerId: 2 });
      await triggerEvent(first, "pointerup", { pointerId: 1 });

      assert
        .dom(document.body)
        .hasClass(
          "dragging",
          "one gesture ending does not unmark the body while another is live"
        );

      await triggerEvent(second, "pointerup", { pointerId: 2 });

      assert
        .dom(document.body)
        .doesNotHaveClass("dragging", "the last one out clears the mark");
    });
  });
});

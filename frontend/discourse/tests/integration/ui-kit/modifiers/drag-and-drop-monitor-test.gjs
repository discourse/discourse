import { hash } from "@ember/helper";
import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

function centerOf(selector) {
  const r = document.querySelector(selector).getBoundingClientRect();
  return { clientX: r.left + r.width / 2, clientY: r.top + r.height / 2 };
}

// PDND batches its `onDragStart` and `onDrag` consumer callbacks through
// `requestAnimationFrame` (via `raf-schd`, see PDND's `dispatch-consumer-event`).
// Ember's `settled()` does not pump animation frames, so right after a synthetic
// `dragstart` / `dragover` those callbacks have not fired yet — and PDND's `drop`
// even cancels a still-pending `onDrag`. Awaiting a real frame lets the batched
// callbacks run before the next event (or an assertion). Our frame resolves after
// PDND's already-queued one, so the queued callback is guaranteed to have fired.
function flushFrame() {
  return new Promise((resolve) => requestAnimationFrame(resolve));
}

// Drives a COMPLETE drag/drop cycle through a real drop target. Every event
// carries finite coords — the monitor resolves the pointer via
// `elementsFromPoint`, which throws on non-finite values. A frame is flushed
// after `dragstart` (so `onDragStart` fires) and after `dragover` (so `onDrag`
// fires before the `drop` cancels it).
async function dragThrough(sourceSelector, targetSelector, { dataTransfer }) {
  const src = centerOf(sourceSelector);
  const tgt = centerOf(targetSelector);
  await triggerEvent(sourceSelector, "dragstart", { dataTransfer, ...src });
  // Fire the rAF-batched `onDragStart` before moving on.
  await flushFrame();
  await triggerEvent(targetSelector, "dragenter", { dataTransfer, ...tgt });
  await triggerEvent(targetSelector, "dragover", { dataTransfer, ...tgt });
  // Fire the rAF-batched `onDrag` now — the `drop` below calls
  // `scheduleOnDrag.cancel()`, so without this flush a still-pending `onDrag`
  // would be cancelled and never observed.
  await flushFrame();
  await triggerEvent(targetSelector, "drop", { dataTransfer, ...tgt });
  await triggerEvent(sourceSelector, "dragend", { dataTransfer, ...tgt });
}

module(
  "Integration | ui-kit | Modifier | dragAndDropMonitor",
  function (hooks) {
    setupRenderingTest(hooks);

    test("observes a matching drag — start, drag, drop", async function (assert) {
      const events = [];

      const onDragStart = () => events.push("start");
      const onDrag = () => events.push("drag");
      const onDrop = () => events.push("drop");

      await render(
        <template>
          {{! The monitor is global; attach it to any sentinel for lifecycle. }}
          <div
            {{dDragAndDropMonitor
              types="row"
              onDragStart=onDragStart
              onDrag=onDrag
              onDrop=onDrop
            }}
          ></div>
          <div id="src" {{dDragAndDropSource type="row" data=(hash id=1)}}>
            src
          </div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      await dragThrough("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.true(events.includes("start"), "onDragStart fired");
      assert.true(events.includes("drag"), "onDrag fired on move");
      assert.true(events.includes("drop"), "onDrop fired when the drag ended");
    });

    test("is type-gated — ignores a non-matching drag", async function (assert) {
      let fired = false;

      const onDragStart = () => {
        fired = true;
      };

      await render(
        <template>
          <div
            {{dDragAndDropMonitor types="card" onDragStart=onDragStart}}
          ></div>
          <div id="src" {{dDragAndDropSource type="row" data=(hash id=1)}}>
            src
          </div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      await dragThrough("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.false(fired, "a `row` drag does not engage a `card` monitor");
    });

    test("observes any drag when no types are given", async function (assert) {
      let started = false;

      const onDragStart = () => {
        started = true;
      };

      await render(
        <template>
          <div {{dDragAndDropMonitor onDragStart=onDragStart}}></div>
          <div id="src" {{dDragAndDropSource type="row" data=(hash id=1)}}>
            src
          </div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      await dragThrough("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.true(started, "untyped monitor engages on any drag");
    });

    test("passes the source payload to the callbacks", async function (assert) {
      let seen = null;

      const onDragStart = ({ source }) => {
        seen = source.data;
      };

      await render(
        <template>
          <div
            {{dDragAndDropMonitor types="row" onDragStart=onDragStart}}
          ></div>
          <div id="src" {{dDragAndDropSource type="row" data=(hash id=2)}}>
            src
          </div>
          <div id="tgt" {{dDragAndDropTarget accepts="row"}}>tgt</div>
        </template>
      );

      await dragThrough("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        seen,
        { type: "row", id: 2 },
        "the monitor callback receives the source's data"
      );
    });
  }
);

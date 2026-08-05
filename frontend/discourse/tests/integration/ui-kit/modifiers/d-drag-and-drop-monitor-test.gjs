import { hash } from "@ember/helper";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { simulateDrag } from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

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

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

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

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

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

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

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

      await simulateDrag("#src", "#tgt", { dataTransfer: new DataTransfer() });

      assert.deepEqual(
        seen,
        { type: "row", id: 2 },
        "the monitor callback receives the source's data"
      );
    });
  }
);

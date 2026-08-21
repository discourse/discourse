import { tracked } from "@glimmer/tracking";
import {
  render,
  resetOnerror,
  settled,
  setupOnerror,
} from "@ember/test-helpers";
import { setupRenderingTest } from "ember-qunit";
import { module, test } from "qunit";
import {
  centerOf,
  dragEvent,
  dragEventNow,
  dragOver,
  resetDragAndDropForTesting,
  startDrag,
  textTransfer,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dDragDwell from "discourse/ui-kit/modifiers/d-drag-dwell";

/* The dwell delay collapses to a 10ms runloop timer under test, which is
   SHORTER than one ~16ms animation frame. Sequences that must run before a
   pending dwell fires therefore use dragEventNow edges in one task — the
   library reports drop-target hierarchy changes synchronously — and every
   element-drag fixture co-locates a drop target on the dwell element so those
   edges exist. `await settled()` resolves the collapsed timer for fire paths. */

const CHIP = "[data-test-chip]";
const DWELL = "[data-test-dwell]";
const INNER = "[data-test-inner]";
const OUTSIDE = "[data-test-outside]";

module("Integration | ui-kit | Modifier | dDragDwell", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    resetDragAndDropForTesting();
  });

  test("dDragDwell fires once the drag has hovered the element", async function (assert) {
    const dwells = [];
    const onDwell = (event) => dwells.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();
    assert.strictEqual(dwells.length, 1, "fires once the delay elapses");

    const event = dwells[0];
    assert.strictEqual(event.family, "element", "family discriminant");
    assert.strictEqual(event.source.type, "card", "normalized source");
    assert.strictEqual(
      event.element,
      document.querySelector(DWELL),
      "the dwell host element"
    );
    assert.true(
      Number.isFinite(event.location.current.input.clientX),
      "location carries the pointer"
    );
  });

  test("dDragDwell fires once per candidacy while frames keep coming", async function (assert) {
    const dwells = [];
    const onDwell = (event) => dwells.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();
    assert.strictEqual(dwells.length, 1, "fired once");

    const point = centerOf(DWELL);
    for (let i = 0; i < 6; i += 1) {
      await dragEvent(DWELL, "dragover", {
        dataTransfer,
        clientX: point.clientX + i,
        clientY: point.clientY,
      });
    }
    await settled();
    assert.strictEqual(
      dwells.length,
      1,
      "continued in-rect frames never re-fire"
    );
  });

  test("dDragDwell leaving before the delay cancels the pending dwell", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
        >folder</div>
        <div
          data-test-outside
          style="display: block; height: 60px; margin-top: 30px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
        >outside</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });

    // Both edges land synchronously in one task, before the collapsed 10ms
    // timer can possibly run.
    dragEventNow(DWELL, "dragenter", { dataTransfer, ...centerOf(DWELL) });
    dragEventNow(OUTSIDE, "dragenter", { dataTransfer, ...centerOf(OUTSIDE) });

    await settled();
    assert.strictEqual(dwells.length, 0, "the cancelled dwell never fires");
    assert.strictEqual(ends.length, 1, "one candidacy ended");
    assert.strictEqual(ends[0].reason, "left", "by leaving");
    assert.false(ends[0].fired, "before firing");
    assert.false(ends[0].droppedHere, "droppedHere is false for a leave");
  });

  test("dDragDwell leaving after the fire reports fired for the undo", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
        >folder</div>
        <div
          data-test-outside
          style="display: block; height: 60px; margin-top: 30px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
        >outside</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();
    assert.strictEqual(dwells.length, 1, "fired");

    await dragEvent(OUTSIDE, "dragenter", {
      dataTransfer,
      ...centerOf(OUTSIDE),
    });
    await settled();
    assert.strictEqual(ends.length, 1, "the candidacy ended");
    assert.strictEqual(ends[0].reason, "left", "by leaving");
    assert.true(ends[0].fired, "after having fired");
  });

  test("dDragDwell reports the drop-target onDrop before onDwellEnd, with droppedHere", async function (assert) {
    const order = [];
    const onTargetDrop = () => order.push("target-drop");
    const onDwell = () => order.push("dwell");
    const onDwellEnd = (event) =>
      order.push(`end:${event.reason}:${event.fired}:${event.droppedHere}`);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget
            accepts="card"
            indicator=false
            onDrop=onTargetDrop
          }}
          {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    await dragEvent(DWELL, "drop", { dataTransfer, ...centerOf(DWELL) });
    await dragEvent(CHIP, "dragend", { dataTransfer, ...centerOf(DWELL) });
    await settled();

    assert.deepEqual(
      order,
      ["dwell", "target-drop", "end:drag-ended:true:true"],
      "the target's onDrop ran before the dwell's end callback, which saw the drop land here"
    );
  });

  test("dDragDwell reports an abandoned drag as drag-ended without droppedHere", async function (assert) {
    const ends = [];
    const onDwell = () => {};
    const onDwellEnd = (event) => ends.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    // A dragend with no drop is the abandon/cancel path; the library empties
    // the targets and still reports the drag's end.
    await dragEvent(CHIP, "dragend", { dataTransfer, ...centerOf(DWELL) });
    await settled();

    assert.strictEqual(ends.length, 1, "the candidacy ended");
    assert.strictEqual(ends[0].reason, "drag-ended", "with the drag");
    assert.true(ends[0].fired, "after having fired");
    assert.false(ends[0].droppedHere, "nothing landed here");
  });

  test("dDragDwell never arms when canDwell refuses", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);
    const refuse = () => false;

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell
            types="card"
            canDwell=refuse
            onDwell=onDwell
            onDwellEnd=onDwellEnd
          }}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    assert.strictEqual(dwells.length, 0, "a refused dwell never fires");
    assert.strictEqual(ends.length, 0, "and no candidacy ever ended");
  });

  test("dDragDwell treats a throwing canDwell as a refusal", async function (assert) {
    const caught = [];
    setupOnerror((error) => caught.push(error));

    try {
      const dwells = [];
      const onDwell = (event) => dwells.push(event);
      const gate = () => {
        throw new Error("gate failure");
      };

      await render(
        <template>
          <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
          <div
            data-test-dwell
            style="display: block; height: 60px;"
            {{dDragAndDropTarget accepts="card" indicator=false}}
            {{dDragDwell types="card" canDwell=gate onDwell=onDwell}}
          >folder</div>
        </template>
      );

      const dataTransfer = new DataTransfer();
      await startDrag(CHIP, { dataTransfer });
      await dragOver(DWELL, { dataTransfer });
      await settled();

      assert.strictEqual(dwells.length, 0, "a throwing gate refuses");
      assert.true(caught.length >= 1, "the throw surfaced through onerror");
    } finally {
      resetOnerror();
    }
  });

  test("dDragDwell clears a pending dwell when canDwell stops qualifying", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);
    let allowed = true;
    const gate = () => allowed;

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell
            types="card"
            canDwell=gate
            onDwell=onDwell
            onDwellEnd=onDwellEnd
          }}
        >
          <div
            data-test-inner
            style="display: block; height: 20px;"
            {{dDragAndDropTarget accepts="card" indicator=false}}
          >inner</div>
        </div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });

    // Arm and re-evaluate synchronously in one task: the inner target changes
    // the hierarchy while the pointer stays inside the dwell rect.
    dragEventNow(DWELL, "dragenter", { dataTransfer, ...centerOf(DWELL) });
    allowed = false;
    dragEventNow(INNER, "dragenter", { dataTransfer, ...centerOf(INNER) });

    await settled();
    assert.strictEqual(dwells.length, 0, "the cleared dwell never fires");
    assert.strictEqual(ends.length, 1, "one candidacy ended");
    assert.strictEqual(ends[0].reason, "left", "reported as a leave");
    assert.false(ends[0].fired, "before firing");
  });

  test("dDragDwell re-validates canDwell at fire time", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);
    let allowed = true;
    const gate = () => allowed;

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" indicator=false}}
          {{dDragDwell
            types="card"
            canDwell=gate
            onDwell=onDwell
            onDwellEnd=onDwellEnd
          }}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });

    dragEventNow(DWELL, "dragenter", { dataTransfer, ...centerOf(DWELL) });
    allowed = false;

    // A pending animation frame may re-check the gate before the timer does;
    // either way the dwell must not fire, and any reported end is a pre-fire
    // leave. Outcome-set assertion by design.
    await settled();
    assert.strictEqual(dwells.length, 0, "the vetoed dwell never fires");
    assert.true(ends.length <= 1, "at most one candidacy ended");
    assert.true(
      ends.every((event) => event.reason === "left" && event.fired === false),
      "any reported end is a pre-fire leave"
    );

    await dragEvent(CHIP, "dragend", { dataTransfer, ...centerOf(DWELL) });
    await settled();
    assert.strictEqual(dwells.length, 0, "still nothing after the drag ends");
  });

  test("dDragDwell ignores element drags outside its types", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="other"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="other" indicator=false}}
          {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    assert.strictEqual(dwells.length, 0, "a filtered drag never dwells");
    assert.strictEqual(ends.length, 0, "and never ends a candidacy");
  });

  test("dDragDwell refuses external drags unless externalKinds opts in", async function (assert) {
    const dwells = [];
    const onDwell = (event) => dwells.push(event);

    await render(
      <template>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragDwell types="card" onDwell=onDwell}}
        >folder</div>
      </template>
    );

    const dataTransfer = textTransfer();
    const point = centerOf(DWELL);
    await dragEvent(DWELL, "dragenter", { dataTransfer, ...point });
    for (let i = 0; i < 4; i += 1) {
      await dragEvent(DWELL, "dragover", { dataTransfer, ...point });
    }
    await settled();

    assert.strictEqual(dwells.length, 0, "no externalKinds, no external dwell");
  });

  test("dDragDwell dwells on an external drag and ends with its drop", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);

    await render(
      <template>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragDwell
            externalKinds="text"
            onDwell=onDwell
            onDwellEnd=onDwellEnd
          }}
        >folder</div>
      </template>
    );

    const dataTransfer = textTransfer();
    const point = centerOf(DWELL);
    await dragEvent(DWELL, "dragenter", { dataTransfer, ...point });
    for (let i = 0; i < 4; i += 1) {
      await dragEvent(DWELL, "dragover", { dataTransfer, ...point });
    }
    await settled();

    assert.strictEqual(dwells.length, 1, "the external drag dwelled");
    assert.strictEqual(dwells[0].family, "external", "family discriminant");
    assert.true(dwells[0].source.containsText(), "the decorated payload");

    await dragEvent(DWELL, "drop", { dataTransfer, ...point });
    await settled();
    assert.strictEqual(ends.length, 1, "the drop ended the candidacy");
    assert.strictEqual(ends[0].reason, "drag-ended", "with the drag");
    assert.true(ends[0].fired, "after having fired");
  });

  test("dDragDwell tears down silently mid-drag", async function (assert) {
    const dwells = [];
    const ends = [];
    const onDwell = (event) => dwells.push(event);
    const onDwellEnd = (event) => ends.push(event);

    class State {
      @tracked show = true;
    }
    const state = new State();

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        {{#if state.show}}
          <div
            data-test-dwell
            style="display: block; height: 60px;"
            {{dDragAndDropTarget accepts="card" indicator=false}}
            {{dDragDwell types="card" onDwell=onDwell onDwellEnd=onDwellEnd}}
          >folder</div>
        {{/if}}
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();
    assert.strictEqual(dwells.length, 1, "fired");

    state.show = false;
    await settled();
    assert.strictEqual(
      ends.length,
      0,
      "teardown mid-drag reports nothing into the dying surface"
    );
  });

  test("dDragDwell refuses the element's own drag when acceptsSelf is false", async function (assert) {
    const dwells = [];
    const onDwell = (event) => dwells.push(event);

    await render(
      <template>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropSource type="card"}}
          {{dDragAndDropTarget
            accepts="card"
            acceptsSelf=false
            indicator=false
          }}
          {{dDragDwell types="card" acceptsSelf=false onDwell=onDwell}}
        >row</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(DWELL, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    assert.strictEqual(dwells.length, 0, "its own drag never dwells");
  });

  test("dDragDwell hands canDwell the shared drop-gate feedback shape", async function (assert) {
    const feedbacks = [];
    const gate = (feedback) => {
      feedbacks.push(feedback);
      return true;
    };
    const onDwell = () => {};

    await render(
      <template>
        <div data-test-chip {{dDragAndDropSource type="card"}}>chip</div>
        <div
          data-test-dwell
          style="display: block; height: 60px;"
          {{dDragAndDropTarget accepts="card" canDrop=gate indicator=false}}
          {{dDragDwell types="card" canDwell=gate onDwell=onDwell}}
        >folder</div>
      </template>
    );

    const dataTransfer = new DataTransfer();
    await startDrag(CHIP, { dataTransfer });
    await dragOver(DWELL, { dataTransfer });
    await settled();

    const dwellFeedback = feedbacks.find((f) => f.family === "element");
    assert.notStrictEqual(
      dwellFeedback,
      undefined,
      "the dwell consulted the shared gate"
    );
    assert.strictEqual(dwellFeedback.source.type, "card", "with the source");
    assert.true(
      Number.isFinite(dwellFeedback.input.clientX),
      "the pointer input"
    );
    assert.strictEqual(
      dwellFeedback.element,
      document.querySelector(DWELL),
      "and the host element"
    );
  });
});

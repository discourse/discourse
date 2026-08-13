import { tracked } from "@glimmer/tracking";
import { clearRender, render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import StickyNote from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/sticky-note";

/**
 * The element a synthetic press can actually reach, ready to receive one.
 *
 * @param {string} selector - The element that will receive the press.
 * @returns {HTMLElement} That element.
 */
function pressable(selector) {
  return stubPointerCapture(selector).element;
}

function noteFixture(overrides = {}) {
  return {
    position: { x: 10, y: 20 },
    size: { width: 200, height: 150 },
    color: "yellow",
    text: "",
    ...overrides,
  };
}

module(
  "Integration | Component | Workflows | Canvas | StickyNote",
  function (hooks) {
    setupRenderingTest(hooks);

    test("dragging only starts once the pointer passes the lenience radius", async function (assert) {
      const moves = [];
      const afterMutations = [];
      const note = noteFixture();
      const onMove = (position) => moves.push(position);
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 100,
        clientY: 100,
      });

      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 102,
        clientY: 101,
      });
      assert.deepEqual(
        moves,
        [],
        "sub-lenience movement does not move the note"
      );

      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 110,
        clientY: 100,
      });
      assert.deepEqual(
        moves,
        [{ x: 20, y: 20 }],
        "past the lenience the note follows the full pointer delta"
      );

      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 110,
        clientY: 100,
      });

      assert.strictEqual(
        afterMutations.length,
        1,
        "the drag end callback still fires"
      );
    });

    test("a click with pointer jitter never moves the note", async function (assert) {
      const moves = [];
      const note = noteFixture({ position: { x: 0, y: 0 } });
      const onMove = (position) => moves.push(position);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onMove={{onMove}} />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 50,
        clientY: 50,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 52,
        clientY: 49,
      });
      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 52,
        clientY: 49,
      });

      assert.deepEqual(moves, [], "the note position never changed");
    });

    test("the pointer delta is divided by the canvas zoom", async function (assert) {
      const moves = [];
      const note = noteFixture({ position: { x: 0, y: 0 } });
      const onMove = (position) => moves.push(position);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{2}} @onMove={{onMove}} />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 20,
      });

      assert.deepEqual(
        moves,
        [{ x: 20, y: 10 }],
        "at 2x zoom the note travels half the pointer distance"
      );
    });

    test("pressing a resize edge resizes without moving the note", async function (assert) {
      const moves = [];
      const resizes = [];
      const note = noteFixture({ position: { x: 10, y: 20 } });
      const onMove = (position) => moves.push(position);
      const onResize = (size) => resizes.push(size);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onResize={{onResize}}
          />
        </template>
      );

      pressable(".workflow-sticky-note");
      const edge = pressable("[data-resize-handle='e']");
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(edge, "pointermove", {
        pointerId: 1,
        clientX: 30,
        clientY: 0,
      });

      assert.deepEqual(
        resizes,
        [{ width: 230, height: 150 }],
        "the east edge grows the width by the pointer delta"
      );
      assert.deepEqual(
        moves,
        [],
        "a trailing edge cannot move the origin, so nothing is emitted for it"
      );
    });

    test("a cancelled note drag still closes the mutation it opened", async function (assert) {
      const afterMutations = [];
      const moves = [];
      const translates = [];
      const note = noteFixture();
      const onAfterMutation = () => afterMutations.push(true);
      const onMove = (position) => moves.push(position);
      const onTranslateSelected = (dx, dy) => translates.push([dx, dy]);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onAfterMutation={{onAfterMutation}}
            @onMove={{onMove}}
            @onTranslateSelected={{onTranslateSelected}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 100,
        clientY: 100,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 120,
        clientY: 100,
      });
      // The OS taking the pointer away. The undo-mutation pair opened at the
      // press must still close, or the canvas is left holding an open mutation.
      await triggerEvent(element, "pointercancel", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });

      assert.strictEqual(
        afterMutations.length,
        1,
        "the interruption closes the mutation the press opened"
      );
      // A cancel is not a release: its coordinates describe no pointer position
      // the user chose. The last move already committed where the note was
      // dragged to, so the interruption must add nothing of its own.
      assert.deepEqual(
        moves,
        [{ x: 30, y: 20 }],
        "the interrupted note keeps where it was dragged to"
      );
      assert.deepEqual(
        translates,
        [[20, 0]],
        "and co-selected notes are not dragged along by the cancel"
      );
    });

    test("a cancelled edge resize still closes the mutation it opened", async function (assert) {
      const afterMutations = [];
      const resizes = [];
      const note = noteFixture();
      const onAfterMutation = () => afterMutations.push(true);
      const onResize = (size) => resizes.push(size);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onAfterMutation={{onAfterMutation}}
            @onResize={{onResize}}
          />
        </template>
      );

      pressable(".workflow-sticky-note");
      const edge = pressable("[data-resize-handle='e']");
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(edge, "pointermove", {
        pointerId: 1,
        clientX: 30,
        clientY: 0,
      });
      await triggerEvent(edge, "pointercancel", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });

      assert.strictEqual(
        afterMutations.length,
        1,
        "the interruption closes the mutation the press opened"
      );
      assert.deepEqual(
        resizes,
        [{ width: 230, height: 150 }],
        "the interrupted box keeps the size it was dragged to"
      );
    });

    test("two edge gestures at once keep their own origins", async function (assert) {
      const resizes = [];
      const note = noteFixture();
      const onResize = (size) => {
        resizes.push(size);
        // Committed the way the canvas commits, which is what makes a second
        // gesture's press-time box differ from the first's.
        note.size = { ...size };
      };

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onResize={{onResize}} />
        </template>
      );

      pressable(".workflow-sticky-note");
      const east = pressable("[data-resize-handle='e']");
      const south = pressable("[data-resize-handle='s']");

      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(east, "pointermove", {
        pointerId: 1,
        clientX: 50,
        clientY: 0,
      });

      // A second finger starts on another edge after the first already grew
      // the note. Its press-time box must not become the first gesture's base.
      await triggerEvent(south, "pointerdown", {
        button: 0,
        pointerId: 2,
        clientX: 0,
        clientY: 0,
      });

      await triggerEvent(east, "pointermove", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });
      await triggerEvent(south, "pointermove", {
        pointerId: 2,
        clientX: 0,
        clientY: 40,
      });

      assert.deepEqual(
        resizes,
        [
          { width: 250, height: 150 },
          { width: 260, height: 150 },
          { width: 260, height: 190 },
        ],
        "each gesture owns its own axis and leaves the other's alone"
      );
    });

    test("opposite edges of one axis compose instead of overwriting", async function (assert) {
      const moves = [];
      const resizes = [];
      const note = noteFixture();
      const onMove = (position) => {
        moves.push(position);
        note.position = { ...position };
      };
      const onResize = (size) => {
        resizes.push(size);
        note.size = { ...size };
      };

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onResize={{onResize}}
          />
        </template>
      );

      pressable(".workflow-sticky-note");
      const west = pressable("[data-resize-handle='w']");
      const east = pressable("[data-resize-handle='e']");

      await triggerEvent(west, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 2,
        clientX: 0,
        clientY: 0,
      });

      // Both gestures own the horizontal axis, one boundary each. Each must move
      // its own edge and leave the other's alone, or the last to report wins and
      // the box loses whichever boundary the other was holding.
      await triggerEvent(east, "pointermove", {
        pointerId: 2,
        clientX: 50,
        clientY: 0,
      });
      await triggerEvent(west, "pointermove", {
        pointerId: 1,
        clientX: -30,
        clientY: 0,
      });

      assert.deepEqual(
        resizes.at(-1),
        { width: 280, height: 150 },
        "the box spans both boundaries, not just the last one dragged"
      );
      assert.deepEqual(
        moves.at(-1),
        { x: -20, y: 20 },
        "and the west edge still carries the origin with it"
      );
    });

    test("two edge gestures at once do not drag each other's position back", async function (assert) {
      const moves = [];
      const note = noteFixture();
      const onMove = (position) => {
        moves.push(position);
        note.position = { ...position };
      };
      const onResize = (size) => {
        note.size = { ...size };
      };

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onResize={{onResize}}
          />
        </template>
      );

      pressable(".workflow-sticky-note");
      const west = pressable("[data-resize-handle='w']");
      const south = pressable("[data-resize-handle='s']");

      await triggerEvent(west, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(south, "pointerdown", {
        button: 0,
        pointerId: 2,
        clientX: 0,
        clientY: 0,
      });

      // West grows the note leftwards, so its origin moves to -50.
      await triggerEvent(west, "pointermove", {
        pointerId: 1,
        clientX: -60,
        clientY: 0,
      });
      // South owns only the vertical axis. It must leave x where west put it;
      // re-asserting its own press-time x would snap the note 60px right.
      await triggerEvent(south, "pointermove", {
        pointerId: 2,
        clientX: 0,
        clientY: 30,
      });

      assert.deepEqual(
        moves.at(-1),
        { x: -50, y: 20 },
        "the vertical gesture leaves the horizontal gesture's origin alone"
      );
    });

    test("a release past the last move commits where the pointer was let go", async function (assert) {
      const resizes = [];
      const note = noteFixture();
      const onResize = (size) => {
        resizes.push(size);
        note.size = { ...size };
      };

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onResize={{onResize}} />
        </template>
      );

      pressable(".workflow-sticky-note");
      const east = pressable("[data-resize-handle='e']");

      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(east, "pointermove", {
        pointerId: 1,
        clientX: 50,
        clientY: 0,
      });
      // The browser can coalesce moves, so the release may carry a newer
      // position than the last move ever reported.
      await triggerEvent(east, "pointerup", {
        pointerId: 1,
        clientX: 80,
        clientY: 0,
      });

      assert.deepEqual(
        resizes.at(-1),
        { width: 280, height: 150 },
        "the committed box is the one the pointer was released at"
      );
    });

    test("a released note drag commits where the pointer was let go", async function (assert) {
      const moves = [];
      const note = noteFixture();
      const onMove = (position) => moves.push(position);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onMove={{onMove}} />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 0,
      });
      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 70,
        clientY: 0,
      });

      assert.deepEqual(
        moves.at(-1),
        { x: 80, y: 20 },
        "the committed position is the one the pointer was released at"
      );
    });

    test("a click on a resize edge resizes nothing", async function (assert) {
      const resizes = [];
      const note = noteFixture();
      const onResize = (size) => resizes.push(size);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onResize={{onResize}} />
        </template>
      );

      pressable(".workflow-sticky-note");
      const east = pressable("[data-resize-handle='e']");

      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(east, "pointerup", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });

      assert.deepEqual(
        resizes,
        [],
        "a press that never moved commits no box of its own"
      );
    });

    test("co-selected notes are translated by the increment, not the total", async function (assert) {
      const translates = [];
      // The note the user grabbed is replaced on every move, the way the canvas
      // replaces it, so a stale read of the previous object would show up here.
      const state = new (class {
        @tracked note = noteFixture();
      })();
      const onMove = (position) => {
        state.note = { ...state.note, position: { ...position } };
      };
      const onTranslateSelected = (dx, dy) => translates.push([dx, dy]);

      await render(
        <template>
          <StickyNote
            @note={{state.note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onTranslateSelected={{onTranslateSelected}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 40,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 70,
        clientY: 0,
      });

      // The others are translated relative to wherever they now sit, so each
      // report must carry only what changed since the previous one. Handing
      // over the running total instead makes them accelerate away.
      assert.deepEqual(
        translates,
        [
          [40, 0],
          [30, 0],
        ],
        "each report carries the step, not the distance from the press"
      );
    });

    test("a second contact on a held handle does not drag the note", async function (assert) {
      const moves = [];
      const note = noteFixture();
      const onMove = (position) => moves.push(position);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onMove={{onMove}} />
        </template>
      );

      pressable(".workflow-sticky-note");
      const east = pressable("[data-resize-handle='e']");

      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      // The handle is already holding a gesture, so it refuses this press. A
      // refused press is not stopped from propagating, so it reaches the note
      // behind the handle, which must not treat it as the start of a note drag.
      await triggerEvent(east, "pointerdown", {
        button: 0,
        pointerId: 2,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(east, "pointermove", {
        pointerId: 2,
        clientX: 60,
        clientY: 0,
      });

      assert.deepEqual(moves, [], "the note stayed where it was");
    });

    test("a click that never moved brackets no mutation at all", async function (assert) {
      const beforeMutations = [];
      const afterMutations = [];
      const note = noteFixture();
      const onBeforeMutation = () => beforeMutations.push(true);
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onBeforeMutation={{onBeforeMutation}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      const edge = pressable("[data-resize-handle='e']");

      // Selecting a note, and a press on the narrow resize strip that never
      // became a drag. Bracketing these captures an undo entry whose before and
      // after are identical, and the history is short enough that a handful of
      // them push the user's real last edit out of reach.
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(edge, "pointerup", {
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });

      assert.deepEqual(beforeMutations, [], "neither click opened a mutation");
      assert.deepEqual(afterMutations, [], "so neither closed one");

      // The positive control: without it, the two assertions above would hold
      // just as well if the mutation wiring had been removed entirely.
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });
      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });

      assert.deepEqual(
        beforeMutations,
        [true],
        "a gesture that really moved opens exactly one"
      );
      assert.deepEqual(afterMutations, [true], "and closes exactly one");
    });

    test("a leading edge stops shrinking at the minimum and stops moving with it", async function (assert) {
      const moves = [];
      const resizes = [];
      const note = noteFixture({ position: { x: 100, y: 100 } });
      const onMove = (position) => moves.push(position);
      const onResize = (size) => resizes.push(size);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onResize={{onResize}}
          />
        </template>
      );

      const edge = pressable("[data-resize-handle='w']");
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      // 500px past the west edge is far beyond the 140px minimum width.
      await triggerEvent(edge, "pointermove", {
        pointerId: 1,
        clientX: 500,
        clientY: 0,
      });

      assert.deepEqual(
        resizes,
        [{ width: 140, height: 150 }],
        "the width clamps at the minimum"
      );
      assert.deepEqual(
        moves,
        [{ x: 160, y: 100 }],
        "the origin only advances by the width the note actually lost"
      );
    });

    test("teardown mid-gesture closes the mutation the press opened", async function (assert) {
      const beforeMutations = [];
      const afterMutations = [];
      const note = noteFixture();
      const onBeforeMutation = () => beforeMutations.push(true);
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onBeforeMutation={{onBeforeMutation}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });

      // The positive control: without it, an assertion that the end fired once
      // could not tell a closed mutation from one that never opened.
      assert.deepEqual(beforeMutations, [true], "the drag opened a mutation");
      assert.deepEqual(afterMutations, [], "and has not closed it yet");

      // The gesture is still held. The drag engine deliberately reports nothing
      // when the element is destroyed, so the consumer has to close its own.
      await clearRender();

      assert.deepEqual(
        afterMutations,
        [true],
        "teardown closes it rather than stranding the undo capture it opened"
      );
    });

    test("teardown after a released gesture does not close it twice", async function (assert) {
      const afterMutations = [];
      const note = noteFixture();
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      const element = pressable(".workflow-sticky-note");
      await triggerEvent(element, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(element, "pointermove", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });
      await triggerEvent(element, "pointerup", {
        pointerId: 1,
        clientX: 60,
        clientY: 0,
      });
      assert.deepEqual(afterMutations, [true], "the release closed it");

      await clearRender();

      assert.deepEqual(
        afterMutations,
        [true],
        "teardown has nothing left to close"
      );
    });

    test("a resize during an edit does not close the edit's mutation", async function (assert) {
      const beforeMutations = [];
      const afterMutations = [];
      const note = noteFixture();
      const onBeforeMutation = () => beforeMutations.push(true);
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onBeforeMutation={{onBeforeMutation}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      await triggerEvent(".workflow-sticky-note", "dblclick");
      assert.deepEqual(beforeMutations, [true], "editing opened one mutation");

      // The press does not move focus, because the gesture cancels it, so the
      // note is still being edited while the resize runs. Both write to the same
      // pair of hooks, so the resize must nest inside the edit rather than open
      // and close a bracket of its own.
      const edge = pressable("[data-resize-handle='e']");
      await triggerEvent(edge, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(edge, "pointermove", {
        pointerId: 1,
        clientX: 30,
        clientY: 0,
      });
      await triggerEvent(edge, "pointerup", {
        pointerId: 1,
        clientX: 30,
        clientY: 0,
      });

      assert.deepEqual(
        beforeMutations,
        [true],
        "the resize did not open a second one"
      );
      assert.deepEqual(
        afterMutations,
        [],
        "and its release did not close the one the edit is still holding"
      );
    });

    test("a throwing mutation hook still leaves the note editable", async function (assert) {
      const afterMutations = [];
      const note = noteFixture();
      const onBeforeMutation = () => {
        throw new Error("owner failure");
      };
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onBeforeMutation={{onBeforeMutation}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      // The hook belongs to the owner and can fail. If the throw were to leave
      // the note flagged as holding an edit it never entered, no textarea would
      // render, so no blur could ever release it and the note could never be
      // edited again.
      const priorOnError = window.onerror;
      // Only the throw under test. Anything else still reaches the harness,
      // which would otherwise go quiet for the whole interaction.
      window.onerror = (...args) =>
        args[4]?.message === "owner failure" || priorOnError?.(...args);
      try {
        await triggerEvent(".workflow-sticky-note", "dblclick");
      } finally {
        window.onerror = priorOnError;
      }

      assert
        .dom(".workflow-sticky-note__textarea")
        .exists("the note entered editing despite the hook throwing");

      // And what the failed hook opened is still releasable. Without this, a
      // note left flagged as editing but not as holding a mutation would pass
      // the assertion above while pinning the count for every later gesture.
      await triggerEvent(".workflow-sticky-note__textarea", "blur");

      assert.deepEqual(
        afterMutations,
        [true],
        "blur releases the mutation the failed hook opened"
      );
    });

    test("teardown mid-edit closes the mutation editing opened", async function (assert) {
      const beforeMutations = [];
      const afterMutations = [];
      const note = noteFixture();
      const onBeforeMutation = () => beforeMutations.push(true);
      const onAfterMutation = () => afterMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onBeforeMutation={{onBeforeMutation}}
            @onAfterMutation={{onAfterMutation}}
          />
        </template>
      );

      // Editing opens a capture on the same wire a gesture does. Removing a
      // focused textarea does not reliably fire blur, so teardown has to close
      // it for the same reason teardown mid-gesture does.
      await triggerEvent(".workflow-sticky-note", "dblclick");

      assert.deepEqual(beforeMutations, [true], "editing opened a mutation");
      assert.deepEqual(afterMutations, [], "and has not closed it yet");

      await clearRender();

      assert.deepEqual(
        afterMutations,
        [true],
        "teardown closes it rather than stranding the undo capture"
      );
    });

    test("pressing the hover toolbar does not drag the note", async function (assert) {
      const moves = [];
      const beforeMutations = [];
      const note = noteFixture({ position: { x: 0, y: 0 } });
      const onMove = (position) => moves.push(position);
      const onBeforeMutation = () => beforeMutations.push(true);

      await render(
        <template>
          <StickyNote
            @note={{note}}
            @zoom={{1}}
            @onMove={{onMove}}
            @onBeforeMutation={{onBeforeMutation}}
          />
        </template>
      );

      pressable(".workflow-sticky-note");
      const toolbar = pressable(".workflow-canvas-toolbar");
      await triggerEvent(toolbar, "pointerdown", {
        button: 0,
        pointerId: 1,
        clientX: 0,
        clientY: 0,
      });
      await triggerEvent(toolbar, "pointermove", {
        pointerId: 1,
        clientX: 60,
        clientY: 60,
      });

      assert.deepEqual(moves, [], "the note never moved");
      assert.deepEqual(
        beforeMutations,
        [],
        "a vetoed press does not open a mutation either"
      );
    });
  }
);

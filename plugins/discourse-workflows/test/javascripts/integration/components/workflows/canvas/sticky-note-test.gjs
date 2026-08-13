import { render, triggerEvent } from "@ember/test-helpers";
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
      const edge = pressable(".workflow-sticky-note__edge--e");
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
        [{ x: 10, y: 20 }],
        "the note keeps its origin, so the press never became a note drag"
      );
    });

    test("a cancelled note drag still closes the mutation it opened", async function (assert) {
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
    });

    test("a cancelled edge resize still closes the mutation it opened", async function (assert) {
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

      pressable(".workflow-sticky-note");
      const edge = pressable(".workflow-sticky-note__edge--e");
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
      const east = pressable(".workflow-sticky-note__edge--e");
      const south = pressable(".workflow-sticky-note__edge--s");

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
          { width: 250, height: 190 },
        ],
        "each gesture resizes from the box it pressed on, not the other's"
      );
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

      const edge = pressable(".workflow-sticky-note__edge--w");
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

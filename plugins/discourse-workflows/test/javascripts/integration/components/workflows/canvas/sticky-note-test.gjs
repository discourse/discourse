import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import StickyNote from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/sticky-note";

function pointerEvent(type, options = {}) {
  return new PointerEvent(type, {
    bubbles: true,
    cancelable: true,
    ...options,
  });
}

module(
  "Integration | Component | Workflows | Canvas | StickyNote",
  function (hooks) {
    setupRenderingTest(hooks);

    test("dragging only starts once the pointer passes the lenience radius", async function (assert) {
      const moves = [];
      const afterMutations = [];
      const note = {
        position: { x: 10, y: 20 },
        size: { width: 200, height: 150 },
        color: "yellow",
        text: "",
      };
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

      const element = find(".workflow-sticky-note");
      element.dispatchEvent(
        pointerEvent("pointerdown", { clientX: 100, clientY: 100 })
      );

      document.dispatchEvent(
        pointerEvent("pointermove", { clientX: 102, clientY: 101 })
      );
      assert.deepEqual(
        moves,
        [],
        "sub-lenience movement does not move the note"
      );

      document.dispatchEvent(
        pointerEvent("pointermove", { clientX: 110, clientY: 100 })
      );
      assert.deepEqual(
        moves,
        [{ x: 20, y: 20 }],
        "past the lenience the note follows the full pointer delta"
      );

      document.dispatchEvent(
        pointerEvent("pointerup", { clientX: 110, clientY: 100 })
      );
      await settled();
      assert.strictEqual(
        afterMutations.length,
        1,
        "the drag end callback still fires"
      );
    });

    test("a click with pointer jitter never moves the note", async function (assert) {
      const moves = [];
      const note = {
        position: { x: 0, y: 0 },
        size: { width: 200, height: 150 },
        color: "yellow",
        text: "",
      };
      const onMove = (position) => moves.push(position);

      await render(
        <template>
          <StickyNote @note={{note}} @zoom={{1}} @onMove={{onMove}} />
        </template>
      );

      const element = find(".workflow-sticky-note");
      element.dispatchEvent(
        pointerEvent("pointerdown", { clientX: 50, clientY: 50 })
      );
      document.dispatchEvent(
        pointerEvent("pointermove", { clientX: 52, clientY: 49 })
      );
      document.dispatchEvent(
        pointerEvent("pointerup", { clientX: 52, clientY: 49 })
      );
      await settled();

      assert.deepEqual(moves, [], "the note position never changed");
    });
  }
);

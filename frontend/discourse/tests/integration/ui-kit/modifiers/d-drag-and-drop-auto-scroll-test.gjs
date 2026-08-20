import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  dragEvent,
  textTransfer,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";

module(
  "Integration | ui-kit | Modifier | dDragAndDropAutoScroll",
  function (hooks) {
    setupRenderingTest(hooks);

    module("external auto-scroll", function () {
      /**
       * Holds a drag near the container's bottom edge across several frames:
       * auto-scroll runs off its own animation-frame loop and eases in over
       * time, so a single event moves nothing measurable.
       */
      async function hoverNearBottomEdge(selector, dataTransfer) {
        const { left, bottom, width } = find(selector).getBoundingClientRect();
        const point = { clientX: left + width / 2, clientY: bottom - 2 };

        await dragEvent(selector, "dragenter", { dataTransfer, ...point });
        for (let frame = 0; frame < 12; frame++) {
          await dragEvent(selector, "dragover", { dataTransfer, ...point });
        }
      }

      const scroller = <template>
        <div
          id="scroller"
          style="height: 100px; overflow-y: auto"
          {{dDragAndDropExternalTarget accepts="text"}}
          {{dDragAndDropAutoScroll accepts=@accepts}}
        >
          <div style="height: 600px">tall</div>
        </div>
      </template>;

      test("external auto-scroll moves the container for a drag from outside the window", async function (assert) {
        await render(<template><scroller @accepts="text" /></template>);

        await hoverNearBottomEdge("#scroller", textTransfer());

        assert.true(
          find("#scroller").scrollTop > 0,
          "holding a drag against the bottom edge scrolls the container down"
        );
      });

      test("external auto-scroll stays off until a consumer asks for it", async function (assert) {
        await render(<template><scroller /></template>);

        await hoverNearBottomEdge("#scroller", textTransfer());

        assert.strictEqual(
          find("#scroller").scrollTop,
          0,
          "a container that named no external kinds is not scrolled by one"
        );
      });
    });
  }
);

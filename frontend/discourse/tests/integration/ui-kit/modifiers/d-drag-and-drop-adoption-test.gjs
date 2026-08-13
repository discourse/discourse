import { hash } from "@ember/helper";
import { find, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  simulateDrag,
  simulateUnsourcedDrag,
} from "discourse/tests/helpers/ui-kit/drag-and-drop-helper";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropSource from "discourse/ui-kit/modifiers/d-drag-and-drop-source";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";

module(
  "Integration | ui-kit | Modifier | dDragAndDropAdoption",
  function (hooks) {
    setupRenderingTest(hooks);

    const WEB_LINK = {
      type: "web-link",
      match: ({ element }) => Boolean(element.closest("a[href]")),
    };

    function linkTransfer() {
      const dataTransfer = new DataTransfer();
      dataTransfer.setData("text/uri-list", "https://example.com/adopted");
      dataTransfer.setData("text/plain", "https://example.com/adopted");
      return dataTransfer;
    }

    module("adopting an unsourced drag", function () {
      test("delivers a browser-started link through the ordinary target", async function (assert) {
        let seen = null;
        const onDrop = ({ source }) => {
          seen = { type: source.type, urls: source.native.getURLs() };
        };

        await render(
          <template>
            <a id="anchor" href="https://example.com/adopted">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#zone", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          seen,
          { type: "web-link", urls: ["https://example.com/adopted"] },
          "the target reports the adoption's type and the snapshotted native payload"
        );
      });

      test("the service reports the adoption without routing keys", async function (assert) {
        // A target strips the adoption's routing keys before a consumer sees
        // them; the service must expose the same shape.
        const dragAndDrop = this.owner.lookup("service:drag-and-drop");

        await render(
          <template>
            <a id="anchor" href="https://example.com/adopted">a link</a>
            <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
          </template>
        );

        const dataTransfer = linkTransfer();
        await dragEvent("#anchor", "dragstart", {
          dataTransfer,
          ...centerOf("#anchor"),
        });

        assert.strictEqual(
          dragAndDrop.currentDrag.type,
          "web-link",
          "currentDrag.type is the adoption's own type"
        );
        assert.deepEqual(
          dragAndDrop.currentDrag.data,
          {},
          "routing keys never reach currentDrag.data"
        );
        assert.deepEqual(
          dragAndDrop.currentDrag.native.getURLs(),
          ["https://example.com/adopted"],
          "the native payload sits beside consumer data"
        );

        await dragEvent("#anchor", "dragend", {
          dataTransfer,
          ...centerOf("#anchor"),
        });

        assert.strictEqual(
          dragAndDrop.currentDrag,
          null,
          "the service clears the adopted drag when it ends"
        );
      });

      test("a target that did not opt in refuses an unsourced drag", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <a id="anchor" href="https://example.com/adopted">a link</a>
            <div id="zone" {{dDragAndDropTarget onDrop=onDrop}}>zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#zone", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "an omitted accepts filter does not admit a drag no source registered"
        );
      });

      test("a registered source is not adopted from under itself", async function (assert) {
        const drops = [];
        const onDrop = ({ source }) => drops.push(source.type);

        await render(
          <template>
            <div id="row" {{dDragAndDropSource type="row" data=(hash id=1)}}>
              <a id="inner" href="https://example.com/adopted">a link</a>
            </div>
            <div
              id="zone"
              {{dDragAndDropTarget accepts="row" adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateDrag("#row", "#zone", { dataTransfer: linkTransfer() });

        assert.deepEqual(
          drops,
          ["row"],
          "the registered source retains its own type and lifecycle"
        );
      });

      test("a dragged text selection is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            {{! A selected URL can produce a dragstart whose payload looks
                exactly like a dragged link. }}
            <a id="inner" href="https://example.com/adopted">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        const range = document.createRange();
        range.selectNodeContents(find("#inner"));
        window.getSelection().removeAllRanges();
        window.getSelection().addRange(range);

        await simulateUnsourcedDrag("#inner", "#zone", {
          dataTransfer: linkTransfer(),
        });

        window.getSelection().removeAllRanges();

        assert.deepEqual(
          drops,
          [],
          "editing text is not repurposed as a drag, however link-shaped its payload"
        );
      });
    });

    module("native browser behavior", function () {
      /**
       * Dispatches dragover and returns the event so the test can observe
       * whether the page claimed it.
       */
      async function dragOverAndReturnEvent(selector, dataTransfer) {
        const event = new DragEvent("dragover", {
          bubbles: true,
          cancelable: true,
          dataTransfer,
          ...centerOf(selector),
        });
        find(selector).dispatchEvent(event);
        await new Promise((resolve) => requestAnimationFrame(resolve));
        return event;
      }

      /**
       * A real `DataTransfer` whose `effectAllowed` retains synthetic writes.
       * The native setter ignores them outside a browser-driven drag data store.
       */
      function recordingTransfer(effectAllowed) {
        const dataTransfer = new DataTransfer();
        Object.defineProperty(dataTransfer, "effectAllowed", {
          value: effectAllowed,
        });
        return dataTransfer;
      }

      test("dead space remains available to the browser", async function (assert) {
        const dataTransfer = linkTransfer();

        await render(
          <template>
            <a id="anchor" href="https://example.com/adopted">a link</a>
            <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
            <div id="nowhere">not a drop target</div>
          </template>
        );

        await dragEvent("#anchor", "dragstart", {
          dataTransfer,
          ...centerOf("#anchor"),
        });

        const event = await dragOverAndReturnEvent("#nowhere", dataTransfer);

        assert.false(
          event.defaultPrevented,
          "an adopted payload can still be dropped somewhere the app does not own"
        );
      });

      test("the browser's allowed effects remain unchanged", async function (assert) {
        const dataTransfer = recordingTransfer("all");
        dataTransfer.setData("text/uri-list", "https://example.com/adopted");

        await render(
          <template>
            <a id="anchor" href="https://example.com/adopted">a link</a>
            <div id="zone" {{dDragAndDropTarget adopts=WEB_LINK}}>zone</div>
          </template>
        );

        await dragEvent("#anchor", "dragstart", {
          dataTransfer,
          ...centerOf("#anchor"),
        });

        assert.strictEqual(
          dataTransfer.effectAllowed,
          "all",
          "adoption does not narrow what the browser permits"
        );
      });
    });

    module("auto-scroll", function () {
      /**
       * Holds a drag near the container's bottom edge across several frames.
       * Auto-scroll eases in over time, so a single event moves nothing.
       */
      async function hoverNearBottomEdge(sourceSelector, dataTransfer) {
        await dragEvent(sourceSelector, "dragstart", {
          dataTransfer,
          ...centerOf(sourceSelector),
        });

        const { left, bottom, width } =
          find("#scroller").getBoundingClientRect();
        const point = { clientX: left + width / 2, clientY: bottom - 2 };

        await dragEvent("#scroller", "dragenter", { dataTransfer, ...point });
        for (let frame = 0; frame < 12; frame++) {
          await dragEvent("#scroller", "dragover", { dataTransfer, ...point });
        }
      }

      const scroller = <template>
        <a id="anchor" href="https://example.com/adopted">a link</a>
        <div id="row" {{dDragAndDropSource type="row"}}>a registered row</div>
        <div
          id="scroller"
          style="height: 100px; overflow-y: auto"
          {{dDragAndDropTarget adopts=WEB_LINK}}
          {{dDragAndDropAutoScroll types=@types}}
        >
          <div style="height: 600px">tall</div>
        </div>
      </template>;

      test("engages for the adoption's declared type", async function (assert) {
        await render(<template><scroller @types="web-link" /></template>);

        await hoverNearBottomEdge("#anchor", linkTransfer());

        assert.true(
          find("#scroller").scrollTop > 0,
          "consumers filter an adopted drag using the type they declared"
        );
      });

      test("ignores an adopted drag of another type", async function (assert) {
        await render(<template><scroller @types="card" /></template>);

        await hoverNearBottomEdge("#anchor", linkTransfer());

        assert.strictEqual(
          find("#scroller").scrollTop,
          0,
          "adoption is not a license to match every browser-started drag"
        );
      });

      test("an adoption type does not match a registered source", async function (assert) {
        await render(<template><scroller @types="web-link" /></template>);

        await hoverNearBottomEdge("#row", linkTransfer());

        assert.strictEqual(
          find("#scroller").scrollTop,
          0,
          "a registered source retains its own type for auto-scroll"
        );
      });
    });
  }
);

import { hash } from "@ember/helper";
import { find, render, setupOnerror } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  centerOf,
  dragEvent,
  fileTransfer,
  simulateDrag,
  simulateUnsourcedDrag,
  textTransfer,
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

    /**
     * Claims anything, so a test can prove a guard refuses a drag before any
     * predicate is consulted.
     */
    const ANY_CONTENT = {
      type: "any-content",
      match: () => true,
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
            <a href="https://example.com/adopted" id="anchor">a link</a>
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
            <a href="https://example.com/adopted" id="anchor">a link</a>
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

      test("an adoption's payload cannot disguise it as a registered source", async function (assert) {
        const spoofing = {
          type: "web-link",
          match: () => true,
          getData: () => ({ id: 7, type: "spoofed", adoptedAs: "spoofed" }),
        };
        let seen = null;
        const onDrop = ({ source }) => {
          seen = { type: source.type, data: source.data };
        };

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=spoofing onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#zone", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          seen,
          { type: "web-link", data: { id: 7 } },
          "the declared type survives and the routing keys reach no consumer"
        );
      });

      test("an adoption cannot pass off another element as the dragged one", async function (assert) {
        const spoofing = {
          type: "web-link",
          match: () => true,
          // The key a handle uses to publish the row it drags on behalf of.
          getData: () => ({ "discourse:dragBody": find("#decoy") }),
        };
        let seen = null;
        const onDrop = ({ source }) => {
          seen = source.element.id;
        };

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div id="decoy">decoy</div>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=spoofing onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#zone", {
          dataTransfer: linkTransfer(),
        });

        assert.strictEqual(
          seen,
          "anchor",
          "a target reports the element the browser dragged, not one the payload named"
        );
      });

      test("nested targets sharing one adoption deliver to the deepest", async function (assert) {
        const drops = [];
        const onOuter = () => drops.push("outer");
        const onInner = () => drops.push("inner");

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="outer"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onOuter}}
            >
              <div
                id="inner"
                {{dDragAndDropTarget adopts=WEB_LINK onDrop=onInner}}
              >inner</div>
            </div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#inner", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          ["inner"],
          "one adoption shared by a zone and its sections lands once, deepest first"
        );
      });

      test("an adopted drag onto its own element lands by default", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <a
              href="https://example.com/adopted"
              id="anchor"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >a link</a>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#anchor", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          ["dropped"],
          "content that is both adoptable and a target accepts its own drag"
        );
      });

      test("an adopted drag onto its own element is refused when acceptsSelf is false", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <a
              href="https://example.com/adopted"
              id="anchor"
              {{dDragAndDropTarget
                acceptsSelf=false
                adopts=WEB_LINK
                onDrop=onDrop
              }}
            >a link</a>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#anchor", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "acceptsSelf governs an adopted drag as it does a registered one"
        );
      });
    });

    module("what adoption refuses", function () {
      test("a target that did not name it refuses an adopted drag", async function (assert) {
        const drops = [];
        const onAdopting = () => drops.push("adopting");
        const onPlain = () => drops.push("plain");

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="adopting"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onAdopting}}
            >adopting</div>
            <div id="plain" {{dDragAndDropTarget onDrop=onPlain}}>plain</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#plain", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "an omitted accepts filter does not admit a drag another target's adoption named"
        );

        await simulateUnsourcedDrag("#anchor", "#adopting", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          ["adopting"],
          "while the target that named it receives the drop"
        );
      });

      test("a target that only adopts refuses a registered source", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <div id="row" {{dDragAndDropSource type="row"}}>a row</div>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateDrag("#row", "#zone", {
          dataTransfer: new DataTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "an omitted accepts filter beside adopts takes no source on the page"
        );
      });

      test("a registered source is not adopted from under itself", async function (assert) {
        const drops = [];
        const onDrop = ({ source }) => drops.push(source.type);

        await render(
          <template>
            <div id="row" {{dDragAndDropSource type="row" data=(hash id=1)}}>
              <a href="https://example.com/adopted" id="inner">a link</a>
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
            <a href="https://example.com/adopted" id="inner">a link</a>
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

      test("a selection dragged out of a text control is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            {{! A text control keeps its selection to itself, so the document
                selection stays collapsed while this one is held. }}
            <textarea id="notes">hello world</textarea>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        find("#notes").setSelectionRange(0, 5);

        await simulateUnsourcedDrag("#notes", "#zone", {
          dataTransfer: textTransfer("hello"),
        });

        assert.deepEqual(
          drops,
          [],
          "text dragged out of a text control is a selection, whatever its payload looks like"
        );
      });

      test("a selection dragged out of a text input is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <input id="query" type="text" value="hello world" />
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        find("#query").setSelectionRange(0, 5);

        await simulateUnsourcedDrag("#query", "#zone", {
          dataTransfer: textTransfer("hello"),
        });

        assert.deepEqual(
          drops,
          [],
          "a single-line control holds a selection the same way a multi-line one does"
        );
      });

      test("a text control that hides its selection offsets is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            {{! Some control types report null offsets rather than a range, so
                whether a selection is held cannot be read back from them. }}
            <input id="address" type="email" value="someone@example.com" />
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#address", "#zone", {
          dataTransfer: textTransfer("someone@example.com"),
        });

        assert.deepEqual(
          drops,
          [],
          "a control that cannot answer is refused rather than adopted"
        );
      });

      test("a text control holding no selection is still adoptable", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <textarea id="notes">hello world</textarea>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#notes", "#zone", {
          dataTransfer: textTransfer("hello"),
        });

        assert.deepEqual(
          drops,
          ["dropped"],
          "the selection is what is refused, not the control it was held in"
        );
      });

      test("a file drag is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#zone", {
          dataTransfer: fileTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "files reach an external target, not this one"
        );
        assert.false(
          find("#anchor").hasAttribute("draggable"),
          "and nothing is registered on the element it started from"
        );
      });

      test("content that declares its own draggable is not adopted", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <div draggable="true" id="widget">a widget</div>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=ANY_CONTENT onDrop=onDrop}}
            >zone</div>
          </template>
        );

        await simulateUnsourcedDrag("#widget", "#zone", {
          dataTransfer: textTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "an element somebody else made draggable keeps its own drag"
        );
        assert.strictEqual(
          find("#widget").getAttribute("draggable"),
          "true",
          "and the attribute adoption would have removed is left alone"
        );
      });
    });

    module("resolving which adoption claims a drag", function () {
      const BOOKMARK = { type: "bookmark", match: () => true };
      const ATTACHMENT = { type: "attachment", match: () => true };

      test("the first live target to match names the drag", async function (assert) {
        const drops = [];
        const onFirst = () => drops.push("first");
        const onSecond = () => drops.push("second");

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="first"
              {{dDragAndDropTarget adopts=BOOKMARK onDrop=onFirst}}
            >first</div>
            <div
              id="second"
              {{dDragAndDropTarget adopts=ATTACHMENT onDrop=onSecond}}
            >second</div>
          </template>
        );

        await simulateUnsourcedDrag("#anchor", "#second", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          [],
          "a later target does not receive a drag the first one already named"
        );

        await simulateUnsourcedDrag("#anchor", "#first", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          ["first"],
          "adoption is resolved once for the page, in target registration order"
        );
      });

      test("a drag the browser refuses releases its adoption", async function (assert) {
        const drops = [];
        const onDrop = () => drops.push("dropped");

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <a href="https://example.com/other" id="other">another link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        // Runs after adoption's window listener and before the drag
        // library's, so the drag it just registered for never begins.
        const refuse = (event) => event.preventDefault();
        document.addEventListener("dragstart", refuse, { capture: true });
        try {
          await dragEvent("#anchor", "dragstart", {
            dataTransfer: linkTransfer(),
            ...centerOf("#anchor"),
          });
        } finally {
          document.removeEventListener("dragstart", refuse, { capture: true });
        }

        assert.false(
          find("#anchor").hasAttribute("draggable"),
          "a drag that never began leaves no registration behind"
        );

        await simulateUnsourcedDrag("#other", "#zone", {
          dataTransfer: linkTransfer(),
        });

        assert.deepEqual(
          drops,
          ["dropped"],
          "and the next drag is adopted normally"
        );
      });
    });

    module("a consumer that throws", function () {
      const blowUp = () => {
        throw new Error("consumer blew up");
      };

      test("a throwing adoption predicate is reported and leaves later ones to decide", async function (assert) {
        const broken = { type: "broken", match: blowUp };
        const reported = [];
        setupOnerror((error) => reported.push(error));

        // setupOnerror only sees the test-time raise. The production report is
        // a separate channel and would go unnoticed if it stopped firing.
        const notices = [];
        const collect = (event) => notices.push(event.detail.messageKey);
        document.addEventListener("discourse-error", collect);

        const drops = [];
        const onDrop = ({ source }) => drops.push(source.type);

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div id="broken" {{dDragAndDropTarget adopts=broken}}>broken</div>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=WEB_LINK onDrop=onDrop}}
            >zone</div>
          </template>
        );

        try {
          await simulateUnsourcedDrag("#anchor", "#zone", {
            dataTransfer: linkTransfer(),
          });

          assert.strictEqual(
            reported.length,
            1,
            "the failure reaches the application rather than vanishing"
          );
          assert.deepEqual(
            notices,
            ["broken_drag_and_drop_alert"],
            "through the channel that reaches admins in production"
          );
          assert.deepEqual(
            drops,
            ["web-link"],
            "and a later adoption still gets to claim the drag"
          );
        } finally {
          document.removeEventListener("discourse-error", collect);
        }
      });

      test("a throwing adoption getData is reported and the drag still lands", async function (assert) {
        const clumsy = { type: "web-link", match: () => true, getData: blowUp };
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const notices = [];
        const collect = (event) => notices.push(event.detail.messageKey);
        document.addEventListener("discourse-error", collect);

        let seen = null;
        const onDrop = ({ source }) => {
          seen = { type: source.type, data: source.data };
        };

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=clumsy onDrop=onDrop}}
            >zone</div>
          </template>
        );

        try {
          await simulateUnsourcedDrag("#anchor", "#zone", {
            dataTransfer: linkTransfer(),
          });

          assert.strictEqual(
            reported.length,
            1,
            "the failure reaches the application rather than vanishing"
          );
          assert.deepEqual(
            notices,
            ["broken_drag_and_drop_alert"],
            "through the channel that reaches admins in production"
          );
          assert.deepEqual(
            seen,
            { type: "web-link", data: {} },
            "and the drag lands carrying no consumer data, rather than not at all"
          );
        } finally {
          document.removeEventListener("discourse-error", collect);
        }
      });
    });

    module("a consumer whose payload throws while it is read", function () {
      test("an adoption payload that throws while being read is reported", async function (assert) {
        const clumsy = {
          type: "web-link",
          match: () => true,
          // Throws while the payload is copied, not while it is built.
          getData: () => ({
            get id() {
              throw new Error("consumer blew up");
            },
          }),
        };
        const reported = [];
        setupOnerror((error) => reported.push(error));

        const notices = [];
        const collect = (event) => notices.push(event.detail.messageKey);
        document.addEventListener("discourse-error", collect);

        let seen = null;
        const onDrop = ({ source }) => {
          seen = { type: source.type, data: source.data };
        };

        await render(
          <template>
            <a href="https://example.com/adopted" id="anchor">a link</a>
            <div
              id="zone"
              {{dDragAndDropTarget adopts=clumsy onDrop=onDrop}}
            >zone</div>
          </template>
        );

        try {
          await simulateUnsourcedDrag("#anchor", "#zone", {
            dataTransfer: linkTransfer(),
          });

          assert.strictEqual(
            reported.length,
            1,
            "reading the payload is inside the boundary, not outside it"
          );
          assert.deepEqual(
            notices,
            ["broken_drag_and_drop_alert"],
            "through the channel that reaches admins in production"
          );
          assert.deepEqual(
            seen,
            { type: "web-link", data: {} },
            "and the drag lands carrying no consumer data"
          );
        } finally {
          document.removeEventListener("discourse-error", collect);
        }
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
            <a href="https://example.com/adopted" id="anchor">a link</a>
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
            <a href="https://example.com/adopted" id="anchor">a link</a>
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
        <a href="https://example.com/adopted" id="anchor">a link</a>
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

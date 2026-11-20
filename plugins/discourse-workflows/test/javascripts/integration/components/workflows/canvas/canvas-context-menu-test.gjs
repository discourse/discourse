import { click, find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import DMenus from "discourse/float-kit/components/d-menus";
import dContextMenu from "discourse/float-kit/modifiers/d-context-menu";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CanvasContextMenu, {
  decideCanvasContextMenu,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-context-menu";

const HOST = ".wf-canvas-host";
const ITEM = ".workflows-canvas__context-menu-item";

/**
 * Dispatches the event the browser sends for a right-click and for the context-menu key
 * alike, and hands it back so a test can see whether anything suppressed the native menu.
 */
async function contextMenu(selector, { clientX = 100, clientY = 100 } = {}) {
  const event = new MouseEvent("contextmenu", {
    bubbles: true,
    cancelable: true,
    clientX,
    clientY,
  });
  find(selector).dispatchEvent(event);
  await settled();
  return event;
}

function itemLabelled(text) {
  return [...document.querySelectorAll(ITEM)].find(
    (button) => button.textContent.trim() === text
  );
}

module(
  "Integration | Component | Workflows | Canvas | CanvasContextMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.containerElement = document.createElement("div");
      this.nodeElement = document.createElement("div");
      this.nodeElement.className = "workflow-rete-node";
      this.nodeElement.dataset.clientId = "node-1";
      this.nodeElement.dataset.unavailable = "false";
      this.containerElement.appendChild(this.nodeElement);
      document
        .getElementById("qunit-fixture")
        .appendChild(this.containerElement);

      this.selected = { nodeIds: new Set(), stickyNoteIds: new Set() };
      this.selectCalls = [];

      this.rete = {
        containerToCanvas: () => ({ x: 10, y: 20 }),
        getSelectedIds: () => this.selected,
        selectableNodes: {
          select: async (...args) => {
            this.selectCalls.push(args);
          },
        },
      };

      this.handlers = {};

      // Mirrors how the canvas wires the modifier, without rendering the whole canvas.
      // The callbacks ride on the decision rather than on a `data=` argument, because
      // dContextMenu spreads the decision last and `decision.data` would overwrite it.
      this.decide = (event) => {
        const decision = decideCanvasContextMenu({
          event,
          rete: this.rete,
          containerElement: this.containerElement,
        });

        if (!decision) {
          return false;
        }

        return { data: { ...decision.data, ...this.handlers } };
      };
    });

    test("wf-ctx: right-clicking a node opens the menu and suppresses the native one", async function (assert) {
      await render(
        <template>
          <div
            class="wf-canvas-host"
            tabindex="0"
            {{dContextMenu
              component=CanvasContextMenu
              beforeContextMenu=this.decide
            }}
          >
            <div class="workflow-rete-node" data-client-id="node-1"></div>
          </div>
          <DMenus />
        </template>
      );

      const event = await contextMenu(`${HOST} .workflow-rete-node`);

      assert.dom(".fk-d-menu").exists("the canvas menu opened");
      assert.true(
        event.defaultPrevented,
        "the browser's own menu is suppressed"
      );
    });

    test("wf-ctx: cut uses the right-clicked node when the rete selection is empty", async function (assert) {
      let cutWith;
      this.handlers = { onCut: (selection) => (cutWith = selection) };

      await render(
        <template>
          <div
            class="wf-canvas-host"
            tabindex="0"
            {{dContextMenu
              component=CanvasContextMenu
              beforeContextMenu=this.decide
            }}
          >
            <div class="workflow-rete-node" data-client-id="node-1"></div>
          </div>
          <DMenus />
        </template>
      );

      await contextMenu(`${HOST} .workflow-rete-node`);
      await click(itemLabelled("Cut"));

      assert.deepEqual(
        cutWith,
        { nodeIds: ["node-1"], stickyNoteIds: [] },
        "the node under the pointer is what gets cut"
      );
    });

    test("wf-ctx: right-clicking inside an existing selection keeps the whole selection", async function (assert) {
      this.selected = {
        nodeIds: new Set(["node-1", "node-2"]),
        stickyNoteIds: new Set(["sticky-9"]),
      };

      const decision = this.decide({
        preventDefault() {},
        clientX: 10,
        clientY: 10,
        target: this.nodeElement,
      });

      assert.deepEqual(
        decision.data.selection.nodeIds.sort(),
        ["node-1", "node-2"],
        "the existing multi-selection survives the right-click"
      );
      assert.deepEqual(
        decision.data.selection.stickyNoteIds,
        ["sticky-9"],
        "selected sticky notes survive too"
      );
      assert.deepEqual(
        this.selectCalls,
        [],
        "nothing is re-selected, because the click landed inside the selection"
      );
    });

    test("wf-ctx: the decision is synchronous even though selecting a node is async", async function (assert) {
      const decision = this.decide({
        preventDefault() {},
        clientX: 10,
        clientY: 10,
        target: this.nodeElement,
      });

      // dContextMenu declines anything thenable, so an async hook opens no menu at all.
      assert.notStrictEqual(
        typeof decision?.then,
        "function",
        "the hook returns a decision, not a promise"
      );
      assert.deepEqual(
        this.selectCalls,
        [["node-1", false]],
        "the node is still selected, without the decision waiting on it"
      );
    });

    test("wf-ctx: right-clicking empty canvas offers canvas actions at that position", async function (assert) {
      const decision = this.decide({
        preventDefault() {},
        clientX: 10,
        clientY: 10,
        target: this.containerElement,
      });

      assert.true(decision.data.isCanvas, "the canvas branch is taken");
      assert.deepEqual(
        decision.data.canvasPos,
        { x: 10, y: 20 },
        "the canvas position is carried for insert actions"
      );
    });

    test("wf-ctx: the context-menu key opens the menu and closing returns focus to the canvas", async function (assert) {
      await render(
        <template>
          <div
            class="wf-canvas-host"
            tabindex="0"
            {{dContextMenu
              component=CanvasContextMenu
              beforeContextMenu=this.decide
            }}
          >
            <div class="workflow-rete-node" data-client-id="node-1"></div>
          </div>
          <DMenus />
        </template>
      );

      find(HOST).focus();
      await contextMenu(`${HOST} .workflow-rete-node`);

      assert.true(
        find(".fk-d-menu").contains(document.activeElement),
        "focus moved into the menu, so the canvas menu is keyboard operable"
      );

      await click(itemLabelled("Cut"));

      assert
        .dom(HOST)
        .isFocused("closing handed focus back to the canvas element");
    });

    test("wf-ctx: invoking an item closes the menu", async function (assert) {
      await render(
        <template>
          <div
            class="wf-canvas-host"
            tabindex="0"
            {{dContextMenu
              component=CanvasContextMenu
              beforeContextMenu=this.decide
            }}
          >
            <div class="workflow-rete-node" data-client-id="node-1"></div>
          </div>
          <DMenus />
        </template>
      );

      await contextMenu(`${HOST} .workflow-rete-node`);
      assert.dom(".fk-d-menu").exists("the menu is open");

      await click(itemLabelled("Cut"));

      assert
        .dom(".fk-d-menu")
        .doesNotExist("acting on an item closed the menu");
    });
  }
);

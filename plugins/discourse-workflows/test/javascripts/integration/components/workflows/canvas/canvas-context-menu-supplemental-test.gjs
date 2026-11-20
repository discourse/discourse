import { clearRender, click, findAll, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CanvasContextMenu, {
  decideCanvasContextMenu,
} from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-context-menu";

const ITEM = ".workflows-canvas__context-menu-item";

module(
  "Integration | Component | Workflows | Canvas | CanvasContextMenu supplemental",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.containerElement = document.createElement("div");
      this.containerElement.getBoundingClientRect = () => ({
        left: 70,
        top: 90,
      });
      this.rete = {
        containerToCanvas: (x, y) => ({ x: x / 2 - 5, y: y / 2 - 10 }),
        getSelectedIds: () => ({
          nodeIds: new Set(["other-node"]),
          stickyNoteIds: new Set(["sticky-1"]),
        }),
        selectableNodes: {
          select: (...args) => {
            this.selectCalls.push(args);
            return new Promise(() => {});
          },
        },
      };
      this.selectCalls = [];
      this.event = {
        clientX: 130,
        clientY: 170,
        target: this.containerElement,
      };
    });

    test("declines before the editor is ready", function (assert) {
      assert.false(
        decideCanvasContextMenu({ event: this.event, rete: null }),
        "an uninitialized canvas keeps the native menu"
      );
    });

    test("converts container offsets and canvas transforms for insertion", function (assert) {
      const decision = decideCanvasContextMenu(this);

      assert.deepEqual(
        decision,
        { data: { isCanvas: true, canvasPos: { x: 25, y: 30 } } },
        "insertion uses transformed coordinates relative to the container"
      );
      assert.deepEqual(
        this.selectCalls,
        [],
        "empty canvas does not select a node"
      );
    });

    test("a nested target replaces an unrelated selection without waiting", function (assert) {
      const node = document.createElement("div");
      node.className = "workflow-rete-node";
      node.dataset.clientId = "clicked-node";
      node.dataset.unavailable = "true";
      const child = document.createElement("span");
      node.appendChild(child);
      this.containerElement.appendChild(node);
      this.event.target = child;

      const decision = decideCanvasContextMenu(this);

      assert.deepEqual(
        decision,
        {
          data: {
            nodeId: "clicked-node",
            selection: { nodeIds: ["clicked-node"], stickyNoteIds: [] },
            isUnavailable: true,
            canvasPos: { x: 25, y: 30 },
          },
        },
        "the pending selection cannot delay or contaminate the clicked node payload"
      );
      assert.deepEqual(
        this.selectCalls,
        [["clicked-node", false]],
        "selection starts without accumulating the unrelated entities"
      );
    });

    test("each item closes before dispatching its data callback", async function (assert) {
      const selection = {
        nodeIds: ["node-1", "node-2"],
        stickyNoteIds: ["sticky-1"],
      };
      const canvasPos = { x: 25, y: 30 };

      for (const [isCanvas, label, callback, payload] of [
        [false, "Edit", "onEditNode", "node-1"],
        [false, "Cut", "onCut", selection],
        [false, "Copy", "onCopy", selection],
        [false, "Paste", "onPaste", canvasPos],
        [false, "Delete", "onDeleteSelected", selection],
        [true, "Add step", "onOpenNodePanel", canvasPos],
        [true, "Add sticky note", "onAddStickyNote", canvasPos],
        [true, "Paste", "onPaste", canvasPos],
      ]) {
        this.data = {
          isCanvas,
          nodeId: "node-1",
          selection,
          canvasPos,
          [callback]: (value) => {
            assert.step(callback);
            assert.deepEqual(value, payload, `${label} receives its payload`);
          },
        };
        this.close = () => assert.step("close");

        await render(
          <template>
            <CanvasContextMenu @close={{this.close}} @data={{this.data}} />
          </template>
        );
        await click(
          findAll(ITEM).find((item) => item.textContent.trim() === label)
        );

        assert.verifySteps(
          ["close", callback],
          `${label} closes before dispatch`
        );
        await clearRender();
      }
    });

    test("unavailable nodes omit Edit but retain selection actions", async function (assert) {
      this.data = { isUnavailable: true };

      await render(
        <template><CanvasContextMenu @data={{this.data}} /></template>
      );

      assert.deepEqual(
        findAll(ITEM).map((item) => item.textContent.trim()),
        ["Cut", "Copy", "Paste", "Delete"],
        "only editing is unavailable"
      );
    });
  }
);

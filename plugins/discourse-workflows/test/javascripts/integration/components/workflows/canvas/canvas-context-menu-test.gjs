import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import CanvasContextMenu from "discourse/plugins/discourse-workflows/admin/components/workflows/canvas/canvas-context-menu";

module(
  "Integration | Component | Workflows | Canvas | CanvasContextMenu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      this.canvasElement = document.createElement("div");
      this.containerElement = document.createElement("div");
      this.nodeElement = document.createElement("div");
      this.nodeElement.className = "workflow-rete-node";
      this.nodeElement.dataset.clientId = "node-1";
      this.nodeElement.dataset.unavailable = "false";

      this.containerElement.appendChild(this.nodeElement);
      document.getElementById("qunit-fixture").appendChild(this.canvasElement);
      document
        .getElementById("qunit-fixture")
        .appendChild(this.containerElement);

      this.rete = {
        containerToCanvas: () => ({ x: 10, y: 20 }),
        getSelectedIds: () => ({
          nodeIds: new Set(),
          stickyNoteIds: new Set(),
        }),
        selectableNodes: {
          select: async () => {},
        },
      };
    });

    test("cut uses the right-clicked node when Rete selection is empty", async function (assert) {
      this.registerContextMenu = (api) => (this.contextMenu = api);
      this.cutSelection = (selection) => {
        this.cutSelectionValue = selection;
      };

      await render(
        <template>
          <CanvasContextMenu
            @canvasElement={{this.canvasElement}}
            @containerElement={{this.containerElement}}
            @rete={{this.rete}}
            @onRegister={{this.registerContextMenu}}
            @onCut={{this.cutSelection}}
          />
        </template>
      );

      await this.contextMenu.open({
        preventDefault() {},
        clientX: 100,
        clientY: 100,
        target: this.nodeElement,
      });
      await settled();

      const cutButton = [
        ...document.querySelectorAll(".workflows-canvas__context-menu-item"),
      ].find((button) => button.textContent.trim() === "Cut");

      await click(cutButton);

      assert.deepEqual(
        this.cutSelectionValue,
        { nodeIds: ["node-1"], stickyNoteIds: [] },
        "the context menu passes the node under the pointer to cut"
      );
    });
  }
);

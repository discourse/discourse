import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { GRID_LAYOUT_SELECTOR } from "discourse/plugins/discourse-wireframe/discourse/lib/grid-dom";

// The editor (grid overlay + cell-resize) locates the layout's CSS Grid
// container with `GRID_LAYOUT_SELECTOR`. If the render-side class drifts from
// that selector, `captureGridElement` finds nothing, `gridElement` stays null,
// the grid drop target is never registered, and EVERY grid drop zone silently
// vanishes. This pins the selector to the class the core `layout` block
// actually renders.
//
//   rendered layout (grid mode)
//   ┌─────────────────────────────┐  <div class="d-block-layout
//   │  ░ cell ░   ░ cell ░         │        d-block-layout--grid"> ← must match
//   └─────────────────────────────┘        GRID_LAYOUT_SELECTOR
module(
  "Integration | discourse-wireframe | grid DOM contract",
  function (hooks) {
    setupRenderingTest(hooks);

    test("the editor's grid selector matches the layout block's rendered grid container", async function (assert) {
      @block("grid-dom-contract-leaf")
      class Leaf extends Component {
        <template>
          <div class="grid-dom-contract-leaf">cell</div>
        </template>
      }

      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: Layout,
            args: { mode: "grid", columns: 3, rows: 1 },
            children: [
              {
                block: Leaf,
                containerArgs: { grid: { column: "1", row: "1" } },
              },
              {
                block: Leaf,
                containerArgs: { grid: { column: "2", row: "1" } },
              },
            ],
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(GRID_LAYOUT_SELECTOR)
        .exists(
          "the editor selector resolves the rendered grid container — otherwise the overlay never mounts and grid drop zones disappear"
        );
    });
  }
);

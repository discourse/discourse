import Component from "@glimmer/component";
import { find, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Layout from "discourse/blocks/builtin/layout";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

// Renders the REAL editor overlay over a grid in edit mode. Unit + service
// tests never mount `GridOverlay`, so a render-time throw in it (a getter that
// errors, an unbound method invoked from the template) tore the component down
// — empty cells vanished and drag-and-drop + resize silently died — without any
// test failing. This suite mounts the overlay so that class of regression fails
// here instead of shipping.

const OUTLET = "main-outlet-blocks";

@block("grid-overlay-rendering-leaf")
class Leaf extends Component {
  <template>
    <div class="grid-overlay-rendering-leaf">cell</div>
  </template>
}

// A 3×2 grid with one filled cell at (1,1), leaving five unoccupied positions
// the overlay should surface as empty cells.
function seedGrid() {
  withPluginApi((api) =>
    api.renderBlocks(OUTLET, [
      {
        block: Layout,
        args: { mode: "grid", columns: 3, rows: 2 },
        children: [
          {
            block: Leaf,
            containerArgs: { grid: { column: "1", row: "1" } },
          },
        ],
      },
    ])
  );
}

// Seeds the grid, renders the outlet, and enters the editor so `BlockChrome`
// wraps the grid and mounts `GridOverlay`. Returns the editor service.
async function renderGridInEditMode(owner) {
  seedGrid();
  const wireframe = owner.lookup("service:wireframe");
  wireframe.siteSettings.wireframe_enabled = true;
  logIn(owner);

  await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

  // Activating the editor flips `BlockChrome` into painting chrome, which is
  // what mounts the overlay. Re-settle so the reactive re-render lands.
  wireframe.enter();
  await settled();

  return wireframe;
}

module(
  "Integration | discourse-wireframe | GridOverlay rendering",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    test("renders empty cells and their resize handles over the grid", async function (assert) {
      await renderGridInEditMode(this.owner);

      assert
        .dom(".wireframe-grid-cell")
        .exists(
          { count: 5 },
          "the overlay renders one empty cell per unoccupied grid position — if the overlay throws at render, none appear"
        );

      assert
        .dom(".wireframe-grid-cell .wireframe-block-chrome__resize-handle")
        .exists("an empty cell carries its merge/resize handles");

      assert
        .dom(
          ".wireframe-block-chrome-wrapper.--in-grid-cell .wireframe-block-chrome__resize-handle"
        )
        .exists(
          "a filled grid cell carries its resize handles too (always in the DOM, CSS-gated to hover / selection)"
        );
    });

    test("selecting reuses each empty cell's DOM instead of rebuilding it", async function (assert) {
      // Guards the keyed `{{#each}}`: the `emptyCells` getter returns new
      // objects every read, so without a stable key a selection change would
      // tear down and rebuild every cell — destroying the resize handle a merge
      // drag just captured the pointer on (the bug that made the drag do
      // nothing).
      const wireframe = await renderGridInEditMode(this.owner);

      assert
        .dom('.wireframe-grid-cell[data-col="2"][data-row="1"]')
        .exists("an empty cell exists before selection changes");
      const before = find('.wireframe-grid-cell[data-col="2"][data-row="1"]');

      // Any selection change recomputes `emptyCells` (it reads the tracked
      // selection). Selecting the grid is enough to trigger the rebuild path.
      const grid = wireframe.layoutQuery.readResolvedLayout(OUTLET)[0];
      wireframe.selectBlock({ key: `layout:${grid.__stableKey}` });
      await settled();

      const after = find('.wireframe-grid-cell[data-col="2"][data-row="1"]');
      assert.strictEqual(
        before,
        after,
        "the empty cell's DOM node is reused across the selection change, not rebuilt"
      );
    });
  }
);

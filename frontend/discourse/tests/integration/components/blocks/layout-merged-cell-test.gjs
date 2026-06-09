import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet from "discourse/blocks/block-outlet";
import Layout, { LayoutMergedCell } from "discourse/blocks/builtin/layout";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

@block("layout-merged-cell-test-content")
class ContentBlock extends Component {
  <template>
    <div class="cell-content">Filled</div>
  </template>
}

// `showGhosts` is the core edit-vs-live signal, backed by the GHOST_BLOCKS
// debug callback. Toggling it here exercises both paths without an editor.
function setShowGhosts(enabled) {
  debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, () => enabled);
}

// A 1-column grid with content in row 1 and a merged cell holding row 2 — the
// second row exists ONLY for the merged cell, so it's the row a live visitor
// should never see.
function renderGridWithMergedRow(api) {
  api.renderBlocks("hero-blocks", [
    {
      block: Layout,
      args: { mode: "grid", columns: 1, rows: 2 },
      children: [
        {
          block: ContentBlock,
          containerArgs: { grid: { column: "1", row: "1" } },
        },
        {
          block: LayoutMergedCell,
          containerArgs: { grid: { column: "1", row: "2" } },
        },
      ],
    },
  ]);
}

module("Integration | Blocks | builtin | layout-merged-cell", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    debugHooks.setCallback(DEBUG_CALLBACK.GHOST_BLOCKS, null);
  });

  test("renders the merged cell's held-open region in an editing context", async function (assert) {
    setShowGhosts(true);
    withPluginApi((api) => renderGridWithMergedRow(api));

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom('[data-block-name="layout-merged-cell"]')
      .exists("the merged cell registers and renders while editing");
    assert
      .dom(".d-block-layout__cell")
      .exists(
        { count: 2 },
        "both the content cell and the merged cell hold a track"
      );
  });

  test("collapses a merged-cell-only row on the live path", async function (assert) {
    setShowGhosts(false);
    withPluginApi((api) => renderGridWithMergedRow(api));

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom('[data-block-name="layout-merged-cell"]')
      .doesNotExist("the merged cell contributes no footprint to visitors");
    assert
      .dom(".d-block-layout__cell")
      .exists(
        { count: 1 },
        "only the content cell remains, so its merged-only row collapses"
      );
    assert
      .dom(".cell-content")
      .exists("content in the surviving track still renders");
  });
});

import Component from "@glimmer/component";
import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { block } from "discourse/blocks";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import ButtonLink from "discourse/blocks/builtin/button-link";
import Layout from "discourse/blocks/builtin/layout";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import {
  BLOCK_ARG_SELECTOR,
  GRID_LAYOUT_SELECTOR,
} from "discourse/plugins/discourse-wireframe/discourse/lib/editor-dom-contract";

// The editor reads DOM that the live-rendered blocks (core) produce. Those
// seams are invisible to logic unit tests and broke once already: a one-line
// class rename in the layout block (wf-layout--grid → d-block-layout--grid)
// silently killed every grid drop zone. This suite renders the REAL producers
// and asserts each selector/attribute the editor depends on still resolves, so
// a producer-side rename fails here instead of shipping a silent regression.
module(
  "Integration | discourse-wireframe | editor DOM contract",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.afterEach(function () {
      _resetOutletLayoutsForTesting();
    });

    // GRID_LAYOUT_SELECTOR — the editor locates the layout's CSS Grid
    // container by this class to mount the overlay + drop target and to
    // measure cells for resize. If it stops resolving, `captureGridElement`
    // returns null, the grid drop target never registers, and grid drag-and-
    // drop silently disappears.
    //
    //   rendered layout (grid mode)
    //   ┌─────────────────────────────┐  <div class="d-block-layout
    //   │  ░ cell ░   ░ cell ░         │        d-block-layout--grid"> ← must
    //   └─────────────────────────────┘        match GRID_LAYOUT_SELECTOR
    test("grid selector matches the layout block's rendered grid container", async function (assert) {
      @block("editor-dom-contract-leaf")
      class Leaf extends Component {
        <template>
          <div class="editor-dom-contract-leaf">cell</div>
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

    // BLOCK_ARG_SELECTOR — core's editable blocks stamp `data-block-arg` on
    // each in-place-editable / image arg element. The editor reads it to wire
    // the URL popover and image-arg overlays. A rename breaks those silently.
    //
    //   rendered button-link
    //   ┌───────────────────────────┐
    //   │ [data-block-arg="href"] …  │ ← must match BLOCK_ARG_SELECTOR
    //   └───────────────────────────┘
    test("block-arg selector matches the arg markers a core editable block renders", async function (assert) {
      withPluginApi((api) =>
        api.renderBlocks("main-outlet-blocks", [
          {
            block: ButtonLink,
            // `href` is required; `icon` satisfies the label/icon atLeastOne
            // constraint without needing a richInline label value.
            args: { href: "https://example.com", icon: "link" },
          },
        ])
      );

      await render(
        <template><BlockOutlet @name="main-outlet-blocks" /></template>
      );

      assert
        .dom(BLOCK_ARG_SELECTOR)
        .exists(
          "the editor's arg-marker selector resolves the block's rendered args — otherwise inline edit / the URL popover / image overlays silently break"
        );
    });
  }
);

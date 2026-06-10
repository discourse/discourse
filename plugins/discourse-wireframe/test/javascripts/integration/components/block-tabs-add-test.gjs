import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import Tabs from "discourse/blocks/builtin/tabs";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/mutate-layout";

const OUTLET = "homepage-blocks";

// After `enter()` the outlet is wrapped in a single root `layout`; its first
// child is the tabs block under test.
function tabsEntry(editor) {
  return editor.readResolvedLayout(OUTLET)?.[0]?.children?.[0];
}

function panelBlockName(editor, panel) {
  return editor.lookupBlockMetadata(panel.block)?.blockName;
}

module(
  "Integration | discourse-wireframe | tabs add-tab affordance",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [
          {
            block: Tabs,
            args: {},
            children: [
              {
                block: Layout,
                args: {},
                children: [{ block: Heading, args: { text: "One" } }],
              },
            ],
          },
        ],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();
    });

    hooks.afterEach(function () {
      this.editor.exit();
      _resetOutletLayoutsForTesting();
    });

    test("clicking the + adds a new layout tab panel", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      assert
        .dom("[data-wf-append-child]")
        .exists("the add-tab affordance renders in the editor");
      assert.strictEqual(
        tabsEntry(this.editor).children.length,
        1,
        "starts with one tab"
      );

      await click("[data-wf-append-child]");

      const panels = tabsEntry(this.editor).children;
      assert.strictEqual(panels.length, 2, "a second tab was added");
      assert.strictEqual(
        panelBlockName(this.editor, panels[1]),
        "layout",
        "the new tab panel is a layout"
      );
    });

    test("clicking a tab selects its panel layout", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      const panelKey = entryKey(tabsEntry(this.editor).children[0]);
      const tab = document.querySelector(".d-block-tabs__tab");
      assert.strictEqual(
        tab.dataset.wfTabPanelKey,
        panelKey,
        "the tab carries its panel layout's key"
      );

      // A real pointer click carries `detail >= 1`; the chrome bails on
      // `detail === 0` (keyboard-synthesized clicks during inline editing), and
      // the tab-selection branch sits after that guard.
      await click(tab, { detail: 1 });

      assert.strictEqual(
        this.editor.selectedBlockKey,
        panelKey,
        "the tab's panel layout is selected (so the inspector targets it)"
      );
    });

    test("clicking an INACTIVE tab selects its panel layout too", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      // Add a second tab; "+" auto-activates the new (last) tab, so the first
      // tab is now inactive.
      await click("[data-wf-append-child]");

      const panels = tabsEntry(this.editor).children;
      assert.strictEqual(panels.length, 2, "two tabs now");
      const firstKey = entryKey(panels[0]);

      // Click the first (now inactive) tab. It must select its panel layout the
      // same way the active tab does.
      const firstTab = document.querySelectorAll(".d-block-tabs__tab")[0];
      await click(firstTab, { detail: 1 });

      assert.strictEqual(
        this.editor.selectedBlockKey,
        firstKey,
        "clicking an inactive tab also selects its panel layout"
      );
    });
  }
);

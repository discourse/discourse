import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
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
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

const OUTLET = "homepage-blocks";

// After `enter()` the outlet is wrapped in a single root `layout`; its first
// child is the tabs block under test.
function tabsEntry(editor) {
  return editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)?.[0]
    ?.children?.[0];
}

function panelBlockName(editor, panel) {
  return editor.wireframeLayoutQuery.lookupBlockMetadata(panel.block)
    ?.blockName;
}

module(
  "Integration | discourse-wireframe | tabs add-tab affordance",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

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

    test("a tab panel's toolbar reads its tab position with left/right move arrows", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      // Add a second tab; it auto-activates and is selected, so its toolbar
      // (with move buttons) renders.
      await click("[data-wf-append-child]");

      // The move arrows on a horizontal container (a tabs strip) point
      // left/right; only the selected block renders them.
      assert
        .dom("[title='Move left']")
        .exists("a horizontal container shows a left move arrow");
      assert
        .dom("[title='Move right']")
        .exists("a horizontal container shows a right move arrow");

      // The selected panel's toolbar badge reads the block name plus a chip
      // for its tab position.
      const toolbar = document
        .querySelector("[title='Move left']")
        .closest(".wireframe-block-toolbar");
      assert.strictEqual(
        toolbar
          ?.querySelector(".wireframe-block-toolbar__handle span")
          ?.textContent.trim(),
        "Layout",
        "the badge reads the block name"
      );
      assert.strictEqual(
        toolbar
          ?.querySelector(".wireframe-block-toolbar__ordinal")
          ?.textContent.trim(),
        "Tab 2",
        "the badge shows the tab position as a chip"
      );
    });

    test("an empty tabs block shows the empty-state call to action with a tab message", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      // Remove the only tab, leaving the tabs block empty.
      const panelKey = entryKey(tabsEntry(this.editor).children[0]);
      this.editor.wireframeBlockMutations.removeBlock(panelKey);
      await settled();

      const remainingPanels = tabsEntry(this.editor)?.children.length ?? 0;
      assert.strictEqual(remainingPanels, 0, "the tabs block has no panels");
      // The shared empty-state placeholder (drag-and-drop + click-to-pick), now
      // also shown for a childBlocks-restricted container, with a tab message.
      assert
        .dom(".wireframe-empty-drop-placeholder__hint")
        .hasText(
          "Add a tab to get started",
          "the empty-state placeholder frames the prompt in tab terms"
        );
      // The tab strip (and its add affordance) is still rendered alongside it.
      assert
        .dom(".d-block-tabs__strip [data-wf-append-child]")
        .exists("the tab strip remains while the tabs block is empty");
    });

    test("reordering a tab focuses the moved tab", async function (assert) {
      await render(<template><BlockOutlet @name={{OUTLET}} /></template>);

      // Add a second tab (now active), so there are two to reorder.
      await click("[data-wf-append-child]");
      const panels = tabsEntry(this.editor).children;
      const firstKey = entryKey(panels[0]);
      const secondKey = entryKey(panels[1]);

      // Move the first (inactive) tab to after the second — the same dispatch a
      // canvas reorder drop produces.
      this.editor.wireframeBlockMutations.moveBlock({
        sourceKey: firstKey,
        targetKey: secondKey,
        position: "after",
        targetOutletName: OUTLET,
      });
      await settled();

      assert.strictEqual(
        this.editor.selectedBlockKey,
        firstKey,
        "the moved tab's panel is selected"
      );
      const activeTab = document.querySelector(
        '.d-block-tabs__tab[aria-selected="true"]'
      );
      assert.strictEqual(
        activeTab?.dataset.wfTabPanelKey,
        firstKey,
        "the moved tab is brought to the front (active)"
      );
    });
  }
);

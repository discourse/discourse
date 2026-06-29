import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import InspectorPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector-panel";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

module(
  "Integration | discourse-wireframe | Component | inspector multi-select",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [
          { block: Heading, args: { text: "One" } },
          { block: Heading, args: { text: "Two" } },
        ],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();

      const draft = outletChildren(this.editor);
      this.firstKey = `heading:${draft[0].__stableKey}`;
      this.secondKey = `heading:${draft[1].__stableKey}`;
    });

    hooks.afterEach(function () {
      this.editor.exit();
    });

    test("shows the per-block form for a single selection", async function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });

      await render(
        <template>
          <div class="wireframe-shell"><InspectorPanel /></div>
        </template>
      );

      assert
        .dom(".wireframe-inspector__multi")
        .doesNotExist("no bulk panel for a single selection");
      assert
        .dom(".wireframe-inspector__header")
        .exists("the single-block form header shows");
    });

    test("shows a bulk-action panel that deletes the whole selection", async function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });
      this.editor.wireframeSelection.toggleBlockSelection({
        key: this.secondKey,
      });

      await render(
        <template>
          <div class="wireframe-shell"><InspectorPanel /></div>
        </template>
      );

      assert.dom(".wireframe-inspector__multi").exists("the bulk panel shows");
      assert
        .dom(".wireframe-inspector__multi-count")
        .hasText("2 blocks selected");

      await click(".wireframe-inspector__multi-delete");

      assert.strictEqual(
        outletChildren(this.editor).length,
        0,
        "both selected blocks are removed"
      );
    });
  }
);

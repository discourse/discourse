import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockToolbar from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-toolbar";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";
import { engineOf, queryOf } from "../../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";
const DUPLICATE = `.wireframe-block-toolbar__btn:has(.d-icon-copy)`;

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

module(
  "Integration | discourse-wireframe | Component | block-toolbar duplicate",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [{ block: Heading, args: { text: "Title" } }],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();

      const draft = outletChildren(this.editor);
      this.blockKey = `heading:${draft[0].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: this.blockKey,
        name: "heading",
      });
    });

    hooks.afterEach(function () {
      this.editor.exit();
    });

    test("the Duplicate button clones the block once", async function (assert) {
      // Wrap in a block-chrome so the editor's document mouseup handler treats
      // the click as in-scope and doesn't deselect before the action runs.
      await render(
        <template>
          <div class="wireframe-block-chrome">
            <BlockToolbar
              @blockKey={{this.blockKey}}
              @outletName={{OUTLET}}
              @displayName="Heading"
              @isSelected={{true}}
            />
          </div>
        </template>
      );

      assert.dom(DUPLICATE).exists("the Duplicate button renders");

      await click(DUPLICATE);
      assert.strictEqual(
        outletChildren(this.editor).length,
        2,
        "the original heading plus one clone"
      );
      assert.true(engineOf(this.editor).canUndo, "the duplicate is undoable");
    });
  }
);

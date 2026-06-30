import { getOwner } from "@ember/owner";
import { click, render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockToolbar from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-toolbar";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";
import { engineOf, queryOf } from "../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

module(
  "Integration | discourse-wireframe | Component | block-toolbar duplicate ×N",
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

    test("renders the Duplicate split-button and its count menu", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @outletName={{OUTLET}}
            @displayName="Heading"
            @isSelected={{true}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__duplicate")
        .exists("the duplicate split-button renders");
      assert
        .dom(".wireframe-duplicate-count-trigger")
        .exists("the count-menu chevron trigger renders");
    });

    test("picking a preset count duplicates the block that many times", async function (assert) {
      // Render the toolbar inside a block-chrome wrapper, as it is in
      // production. The editor's document-level mouseup handler deselects the
      // block when a click lands outside the editor's "allowed scope" (block
      // chrome, the shell, an open menu); without this wrapper the trigger sits
      // outside that scope, so clicking it would deselect and the menu would
      // never open.
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

      await click(".wireframe-duplicate-count-trigger");
      // The "× 3" preset is the third item in the dropdown.
      const presets = document.querySelectorAll(
        ".wireframe-duplicate-count-content .dropdown-menu__item .btn"
      );
      await click(presets[1]); // ×3

      assert.strictEqual(
        outletChildren(this.editor).length,
        4,
        "the original heading plus three clones"
      );
      await settled();
      assert.true(
        engineOf(this.editor).canUndo,
        "the ×N duplicate is undoable"
      );
    });
  }
);

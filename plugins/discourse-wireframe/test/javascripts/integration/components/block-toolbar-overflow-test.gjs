import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockToolbar from "discourse/plugins/discourse-wireframe/discourse/components/editor/block-toolbar";
import { setupBlockLayoutDraftsStub } from "../../helpers/stub-block-layout-drafts";

const OUTLET = "homepage-blocks";

function outletChildren(editor) {
  return (
    editor.wireframeLayoutQuery.readResolvedLayout(OUTLET)?.[0]?.children ?? []
  );
}

module(
  "Integration | discourse-wireframe | Component | block-toolbar overflow",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [{ block: Heading, args: { text: "Title" } }],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe");
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

    test("a movable block renders the inline action row and a hamburger", async function (assert) {
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
        .dom(".wireframe-block-toolbar__actions")
        .exists("the collapsible inline action row renders");
      assert
        .dom(".wireframe-block-toolbar__actions .d-icon-arrow-up")
        .exists("move-back is inline");
      assert
        .dom(".wireframe-block-toolbar__actions .d-icon-trash-can")
        .exists("delete is inline");
      assert
        .dom(".wireframe-block-toolbar__more")
        .exists("the hamburger trigger renders for a movable block");
    });

    test("the hamburger menu holds the same structural actions as the inline row", async function (assert) {
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

      // Synthetic clicks ignore the CSS that hides the off-tier hamburger, so
      // this opens the menu regardless of the (unconstrained) test width.
      await click(".wireframe-block-toolbar__more");

      const menu = ".wireframe-toolbar-more-content";
      assert.dom(menu).exists("the hamburger menu opens");
      assert
        .dom(`${menu} .d-icon-arrow-up`)
        .exists("move-back is available in the menu");
      assert
        .dom(`${menu} .d-icon-copy`)
        .exists("duplicate is available in the menu");
      assert
        .dom(`${menu} .d-icon-trash-can`)
        .exists("delete is available in the menu");
    });

    test("an outlet root is identity-only — no hamburger, no structural actions", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @outletName={{OUTLET}}
            @displayName="Hero"
            @isOutletRoot={{true}}
            @isSelected={{true}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__handle--outlet")
        .exists("the outlet identity handle renders");
      assert
        .dom(".wireframe-block-toolbar__more")
        .doesNotExist("an outlet root never shows the hamburger");
      assert
        .dom(".wireframe-block-toolbar__actions .d-icon-trash-can")
        .doesNotExist("an outlet root can't be deleted, so no delete action");
    });
  }
);

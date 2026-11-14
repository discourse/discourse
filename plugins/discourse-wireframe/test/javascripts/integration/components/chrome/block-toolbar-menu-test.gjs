import { hash } from "@ember/helper";
import { getOwner } from "@ember/owner";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import {
  _renderBlocks,
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import Layout from "discourse/blocks/builtin/layout";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockToolbar from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-toolbar";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";
const MENU = ".wireframe-toolbar-more-content";

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

module(
  "Integration | discourse-wireframe | Component | block-toolbar strip",
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

    test("a movable block's strip names it and holds the gear and the menu trigger", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Heading"
            @isSelected={{true}}
            @outletName={{OUTLET}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__name")
        .hasText("Heading", "the strip names the block");
      assert
        .dom(".wireframe-block-toolbar__handle .d-icon-grip-vertical")
        .exists("the grip is the drag handle");
      assert
        .dom(".wireframe-block-toolbar__settings")
        .exists("the gear opens the inspector");
      assert
        .dom(".wireframe-block-toolbar__more")
        .exists("the menu trigger renders for a movable block");
      assert
        .dom(".wireframe-block-toolbar__actions .d-icon-trash-can")
        .doesNotExist("structural actions live in the menu, not inline");
    });

    test("the menu holds the structural actions in order", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Heading"
            @isSelected={{true}}
            @outletName={{OUTLET}}
          />
        </template>
      );

      await click(".wireframe-block-toolbar__more");
      assert.dom(MENU).exists("the menu opens");

      const ids = [
        ...document.querySelectorAll(`${MENU} [data-toolbar-action]`),
      ].map((el) => el.dataset.toolbarAction);
      assert.deepEqual(
        ids,
        ["duplicate", "move-back", "move-forward", "delete"],
        "a top-level block offers duplicate, move, and remove — its parent is the outlet, so no select-parent"
      );
      assert
        .dom(`${MENU} [data-toolbar-action='move-back']`)
        .isDisabled("the only block can't move up");
      assert
        .dom(`${MENU} [data-toolbar-action='delete']`)
        .hasClass(
          "wireframe-block-toolbar__menu-item--danger",
          "remove reads as destructive"
        );
    });

    test("an outlet root is identity-only — publish state, no gear, no menu", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Homepage"
            @isOutletRoot={{true}}
            @isSelected={{true}}
            @outletName={{OUTLET}}
            @outletState="published"
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__handle--outlet")
        .exists("the outlet identity handle renders");
      assert
        .dom(".wireframe-block-toolbar__status--publish.--published")
        .hasText("Published", "the outlet strip shows its publish state");
      assert
        .dom(".wireframe-block-toolbar__settings")
        .doesNotExist("an outlet root has no gear");
      assert
        .dom(".wireframe-block-toolbar__more")
        .doesNotExist("an outlet root with no actions shows no menu");
    });

    test("an outlet with unsaved edits reads as unpublished changes", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Homepage"
            @isOutletEditing={{true}}
            @isOutletRoot={{true}}
            @outletName={{OUTLET}}
            @outletState="published"
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__status--publish.--unpublished_changes")
        .hasText("Unpublished changes");
    });

    test("a hidden block's strip summarises why", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Heading"
            @failureType={{FAILURE_TYPE.CONDITION_FAILED}}
            @isGhost={{true}}
            @isSelected={{true}}
            @outletName={{OUTLET}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__status[data-wf-status='hidden']")
        .hasText("Hidden by conditions");
    });

    test("a deeply nested selection folds its middle ancestors behind a menu", async function (assert) {
      // Rebuild the outlet as outlet > layout > layout > heading and select the
      // heading, so its ancestry (outlet, the two layouts) is three deep. The
      // sibling heading keeps the outlet's implicit root a wrapper, so the outer
      // layout stays an ancestor rather than becoming the root itself.
      this.editor.exit();
      _resetOutletLayoutsForTesting();
      await _renderBlocks(
        OUTLET,
        [
          { block: Heading, args: { text: "Other" } },
          {
            block: Layout,
            children: [
              {
                block: Layout,
                children: [{ block: Heading, args: { text: "Deep" } }],
              },
            ],
          },
        ],
        getOwner(this)
      );
      this.editor.enter();
      const outer = outletChildren(this.editor)[1];
      const inner = outer.children[0];
      const heading = inner.children[0];
      const headingKey = `heading:${heading.__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: headingKey,
        name: "heading",
      });

      await render(
        <template>
          <div class="wireframe-block-chrome">
            <BlockToolbar
              @blockKey={{headingKey}}
              @displayName="Heading"
              @isNested={{true}}
              @isSelected={{true}}
              @outletName={{OUTLET}}
            />
          </div>
        </template>
      );

      const crumbs = [
        ...document.querySelectorAll(
          ".wireframe-block-toolbar__crumb:not(.wireframe-block-toolbar__crumb--folded)"
        ),
      ].map((el) => el.textContent.trim());
      assert.strictEqual(
        crumbs.length,
        2,
        "only the outlet and the immediate parent stay inline"
      );
      assert.strictEqual(
        crumbs[1],
        "Stack",
        "the immediate parent is the inner layout"
      );
      assert
        .dom(".wireframe-block-toolbar__name")
        .hasText("Heading", "the block's own name ends the breadcrumb");
      assert
        .dom(".wireframe-block-toolbar__crumb--folded")
        .exists("the middle ancestor folds behind a menu trigger");

      await click(".wireframe-block-toolbar__crumb--folded");
      const folded =
        ".wireframe-strip-crumbs-content .wireframe-block-toolbar__menu-item";
      assert
        .dom(folded)
        .exists({ count: 1 }, "the menu lists the folded ancestor");

      await click(folded);
      assert.strictEqual(
        this.editor.wireframeSelection.selectedBlockKey,
        `layout:${outer.__stableKey}`,
        "picking a folded ancestor selects it"
      );
    });

    test("a condition shows as a status, with the rest in the title", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @conditions={{array
              (hash type="viewport" min="lg")
              (hash type="user" staff=true)
            }}
            @displayName="Heading"
            @isSelected={{true}}
            @outletName={{OUTLET}}
          />
        </template>
      );

      assert
        .dom(".wireframe-block-toolbar__status[data-wf-status='viewport']")
        .hasText("Desktop and up", "the first condition is the visible status");
      assert
        .dom(".wireframe-block-toolbar__status")
        .hasAttribute(
          "title",
          "Desktop and up · Staff only",
          "every status is listed in the tooltip"
        );
    });
  }
);

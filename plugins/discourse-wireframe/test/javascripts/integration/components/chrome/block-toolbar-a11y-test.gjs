import { getOwner } from "@ember/owner";
import { click, focus, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import BlockToolbar from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-toolbar";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../../helpers/wireframe-peers";

const OUTLET = "homepage-blocks";
const TOOLBAR = ".wireframe-block-toolbar[role='toolbar']";
const BTN = ".wireframe-block-toolbar__btn";
const SETTINGS = `${BTN}:has(.d-icon-gear)`;
const MORE = `${BTN}:has(.d-icon-ellipsis)`;
const URL_INPUT = ".wireframe-block-toolbar__url-input";

function outletChildren(editor) {
  return queryOf(editor).readResolvedLayout(OUTLET)?.[0]?.children ?? [];
}

// Admin plugin SCSS isn't loaded in rendering tests, so the hover-only
// visibility never applies — these tests assert the keyboard contract
// (labelling, roving tabindex, focus restoration), never visibility.
module(
  "Integration | discourse-wireframe | Component | block-toolbar a11y",
  function (hooks) {
    setupRenderingTest(hooks);
    setupBlockLayoutDraftsStub(hooks);

    hooks.beforeEach(async function () {
      await _renderBlocks(
        OUTLET,
        [
          { block: Heading, args: { text: "One" } },
          { block: Heading, args: { text: "Two" } },
          { block: Heading, args: { text: "Three" } },
          { block: Heading, args: { text: "Four" } },
        ],
        getOwner(this)
      );
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
      this.editor.siteSettings.wireframe_enabled = true;
      logIn(getOwner(this));
      this.editor.enter();

      // Select the SECOND block: it sits at neither edge, so both move arrows
      // stay enabled and the roving cursor / post-move focus are deterministic.
      const draft = outletChildren(this.editor);
      this.blockKey = `heading:${draft[1].__stableKey}`;
      this.editor.wireframeSelection.selectBlock({
        key: this.blockKey,
        name: "heading",
      });
    });

    hooks.afterEach(function () {
      this.editor.exit();
    });

    test("the selected toolbar is a labelled, single-tab-stop toolbar", async function (assert) {
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
        .dom(TOOLBAR)
        .hasAttribute(
          "aria-label",
          "Heading block toolbar",
          "the toolbar is named for assistive tech"
        );
      assert
        .dom(TOOLBAR)
        .doesNotHaveAttribute(
          "aria-hidden",
          "a selected toolbar stays exposed to assistive tech"
        );

      const tabStops = document.querySelectorAll(`${BTN}[tabindex='0']`);
      assert.strictEqual(
        tabStops.length,
        1,
        "exactly one button is in the Tab order (roving tabindex)"
      );
    });

    test("arrow keys move focus and the single tab stop follows", async function (assert) {
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

      // The gear is the first action, so it seeds the single tab stop.
      assert
        .dom(SETTINGS)
        .hasAttribute("tabindex", "0", "the first button is the tab stop");

      await focus(SETTINGS);
      await triggerKeyEvent(SETTINGS, "keydown", "ArrowRight");
      assert.dom(MORE).isFocused("ArrowRight moves focus to the next button");
      assert
        .dom(MORE)
        .hasAttribute("tabindex", "0", "the tab stop follows focus");
      assert.dom(SETTINGS).hasAttribute("tabindex", "-1");
    });

    test("a top-level block's menu offers no select-parent — its parent is the outlet", async function (assert) {
      await render(
        <template>
          <div class="wireframe-block-chrome">
            <BlockToolbar
              @blockKey={{this.blockKey}}
              @displayName="Heading"
              @isSelected={{true}}
              @outletName={{OUTLET}}
            />
          </div>
        </template>
      );

      await click(MORE);
      assert
        .dom(".wireframe-toolbar-more-content [data-toolbar-action]")
        .exists("the menu opens with actions");
      assert
        .dom(
          ".wireframe-toolbar-more-content [data-toolbar-action='select-parent']"
        )
        .doesNotExist("stepping up to the outlet itself isn't offered");
    });

    test("an idle, unselected toolbar is hidden from assistive tech", async function (assert) {
      await render(
        <template>
          <BlockToolbar
            @blockKey={{this.blockKey}}
            @displayName="Heading"
            @isSelected={{false}}
            @outletName={{OUTLET}}
          />
        </template>
      );

      assert
        .dom(TOOLBAR)
        .hasAttribute(
          "aria-hidden",
          "true",
          "an idle toolbar doesn't leak a phantom toolbar to assistive tech"
        );
    });

    test("the URL field keeps its own caret keys", async function (assert) {
      // Put the toolbar in link-URL mode the way the rich-text controller does.
      const inplaceText = getOwner(this).lookup(
        "service:wireframe-inplace-text"
      );
      inplaceText.setFieldEditor({
        kind: "url",
        value: "https://example.com",
        apply: () => {},
        cancel: () => {},
        remove: () => {},
      });

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

      await focus(URL_INPUT);
      await triggerKeyEvent(URL_INPUT, "keydown", "ArrowRight");
      assert
        .dom(URL_INPUT)
        .isFocused("ArrowRight stays in the URL field instead of navigating");

      await triggerKeyEvent(URL_INPUT, "keydown", "Home");
      assert
        .dom(URL_INPUT)
        .isFocused("Home stays in the URL field, not jumping to a button");
    });
  }
);

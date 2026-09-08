import { getOwner } from "@ember/owner";
import {
  click,
  find,
  focus,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import { _renderBlocks } from "discourse/blocks/block-outlet";
import Heading from "discourse/blocks/builtin/heading";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { logIn } from "discourse/tests/helpers/qunit-helpers";
import InspectorPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-panel";
import { entryKey } from "discourse/plugins/discourse-wireframe/discourse/lib/layout/mutate-layout";
import { setupBlockLayoutDraftsStub } from "../../../helpers/stub-block-layout-drafts";
import { queryOf } from "../../../helpers/wireframe-peers";

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
      this.editor = getOwner(this).lookup("service:wireframe-workspace");
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

    test("DTabs adoption preserves inspector selection and conditional-tab fallback", async function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });
      await render(
        <template>
          <div class="wireframe-shell"><InspectorPanel /></div>
        </template>
      );
      const args = '.wireframe-inspector__tab[data-d-tab="args"]';
      const conditions = '.wireframe-inspector__tab[data-d-tab="conditions"]';
      await focus(args);
      await triggerKeyEvent(args, "keydown", "ArrowRight");
      assert.dom(conditions).isFocused("arrow focus reaches Conditions");
      assert
        .dom(args)
        .hasAttribute(
          "aria-selected",
          "true",
          "focus alone leaves Settings active"
        );
      await triggerKeyEvent(conditions, "keydown", "Enter");
      assert
        .dom(conditions)
        .hasAttribute("aria-selected", "true", "Enter activates Conditions");
      assert
        .dom('.wireframe-inspector__sections > [role="tabpanel"]')
        .hasAttribute(
          "aria-labelledby",
          find(conditions).id,
          "the panel is labelled by its active tab"
        );
      const root = queryOf(this.editor).readResolvedLayout(OUTLET)[0];
      this.editor.wireframeSelection.selectBlock({ key: entryKey(root) });
      await settled();
      assert
        .dom(conditions)
        .doesNotExist("outlet roots do not expose Conditions");
      assert
        .dom(args)
        .hasAttribute(
          "aria-selected",
          "true",
          "the consumer falls back to Settings"
        );
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

    test("shows a block preview beside the name for a single selection", async function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });

      await render(
        <template>
          <div class="wireframe-shell"><InspectorPanel /></div>
        </template>
      );

      assert
        .dom(".wireframe-inspector__header .wireframe-inspector__thumbnail")
        .exists("the selected block's preview renders beside its name");
    });

    test("shows no block preview for a multi-selection", async function (assert) {
      this.editor.wireframeSelection.selectBlock({ key: this.firstKey });
      this.editor.wireframeSelection.toggleBlockSelection({
        key: this.secondKey,
      });

      await render(
        <template>
          <div class="wireframe-shell"><InspectorPanel /></div>
        </template>
      );

      assert
        .dom(".wireframe-inspector__thumbnail")
        .doesNotExist("the bulk panel shows no single-block preview");
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

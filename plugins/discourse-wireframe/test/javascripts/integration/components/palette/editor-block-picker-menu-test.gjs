import Service from "@ember/service";
import { click, fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import EditorBlockPickerMenu from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/editor-block-picker-menu";

const PALETTE = [
  { name: "quote", displayName: "Quote", icon: "quote-left", description: "" },
  { name: "heading", displayName: "Heading", icon: "heading", description: "" },
  { name: "image", displayName: "Image", icon: "image", description: "" },
  {
    name: "paragraph",
    displayName: "Paragraph",
    icon: "align-left",
    description: "",
  },
];

function labels() {
  return [...document.querySelectorAll(".wireframe-block-tile__label")].map(
    (el) => el.textContent.trim()
  );
}

module(
  "Integration | discourse-wireframe | Component | editor-block-picker-menu",
  function (hooks) {
    setupRenderingTest(hooks);

    hooks.beforeEach(function () {
      // Decouple from outlet registration — exercise the inserter's own
      // ordering/search/browse-all, not the drop-authority rules.
      this.owner.register(
        "service:wireframe-drop-authority",
        class extends Service {
          canInsertBlockAt() {
            return true;
          }
        }
      );
    });

    test("floats the curated blocks to the top of the suggestions", async function (assert) {
      const data = { palette: PALETTE, targetOutletName: "x", onPick() {} };
      await render(
        <template><EditorBlockPickerMenu @data={{data}} /></template>
      );

      assert.deepEqual(
        labels(),
        ["Paragraph", "Heading", "Image", "Quote"],
        "paragraph/heading/image lead, the rest follow"
      );
    });

    test("search filters the suggestions", async function (assert) {
      const data = { palette: PALETTE, targetOutletName: "x", onPick() {} };
      await render(
        <template><EditorBlockPickerMenu @data={{data}} /></template>
      );

      await fillIn(".wireframe-block-picker__search", "quote");
      assert.deepEqual(labels(), ["Quote"], "only matching blocks remain");
    });

    test("shows an empty state when nothing matches", async function (assert) {
      const data = { palette: PALETTE, targetOutletName: "x", onPick() {} };
      await render(
        <template><EditorBlockPickerMenu @data={{data}} /></template>
      );

      await fillIn(".wireframe-block-picker__search", "definitely-nothing");
      assert.dom(".wireframe-block-tile").doesNotExist();
      assert.dom(".wireframe-block-picker__empty").exists();
    });

    test("picking a tile fires onPick with the row", async function (assert) {
      let picked = null;
      const data = {
        palette: PALETTE,
        targetOutletName: "x",
        onPick: (entry) => (picked = entry),
      };
      await render(
        <template><EditorBlockPickerMenu @data={{data}} /></template>
      );

      await click(".wireframe-block-tile"); // first suggestion (Paragraph)
      assert.strictEqual(picked?.name, "paragraph");
    });

    test("Browse all reveals the sidebar palette and closes the menu", async function (assert) {
      const rail = this.owner.lookup("service:wireframe-rail");
      rail.setLeftPanelTab("outline");
      let closed = false;
      const data = { palette: PALETTE, targetOutletName: "x", onPick() {} };
      const close = () => (closed = true);

      await render(
        <template>
          <EditorBlockPickerMenu @data={{data}} @close={{close}} />
        </template>
      );

      await click(".wireframe-block-picker__browse-all");
      assert.strictEqual(
        rail.leftPanelTab,
        "palette",
        "switches the rail to the palette"
      );
      assert.true(closed, "dismisses the inserter menu");
    });
  }
);

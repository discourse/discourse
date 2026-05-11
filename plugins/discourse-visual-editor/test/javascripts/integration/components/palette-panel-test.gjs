import { fillIn, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PalettePanel from "discourse/plugins/discourse-visual-editor/discourse/components/editor/palette-panel";

module(
  "Integration | discourse-visual-editor | Component | palette-panel",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders at least one entry per registered starter block", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The 8 starter blocks shipped by Phase 6e plus any core built-ins
      // (`head`, `group`) auto-register before tests run, so the palette
      // should have at least 8 entries.
      assert.dom(".visual-editor-palette-entry").exists();
      const entries = document.querySelectorAll(".visual-editor-palette-entry");
      assert.true(entries.length >= 8);
    });

    test("filters by the search input", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".visual-editor-palette__search", "paragraph");
      assert
        .dom(".visual-editor-palette-entry")
        .exists({ count: 1 }, "only Paragraph matches 'paragraph'");
      assert.dom(".visual-editor-palette-entry").hasText(/Paragraph/);
    });

    test("renders the empty state when no entries match", async function (assert) {
      await render(<template><PalettePanel /></template>);

      await fillIn(".visual-editor-palette__search", "definitely-no-match");
      assert.dom(".visual-editor-palette-entry").doesNotExist();
      assert.dom(".visual-editor-palette .panel-empty").exists();
    });

    test("category chips render at least the namespace types we expect", async function (assert) {
      await render(<template><PalettePanel /></template>);

      // The starter blocks are all "plugin" namespace; we expect at
      // least the "Plugin" chip plus the block-author categories
      // (Content, Layout, Navigation, Data) — chip labels are i18n'd
      // for namespace keys and raw for arbitrary categories.
      const chips = [
        ...document.querySelectorAll(".visual-editor-palette__chip"),
      ].map((el) => el.textContent.trim());
      assert.true(chips.includes("Content"));
      assert.true(chips.includes("Layout"));
      assert.true(chips.includes("Navigation"));
      assert.true(chips.includes("Data"));
    });
  }
);
